# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        # Object
        def object_class(_, v) = v.class_object
        def object_ivar_get(_, v, name)    = v.get_ivar(validated_ivar(name, v))
        def object_ivar_defined(_, v, name) = n2f_bool(v.ivar_defined?(validated_ivar(name, v)))
        def object_ivar_names(_, v) = n2f_arr((v.instance_variables_hash&.keys || []).map { |k| n2f_sym(k) })
        def object_freeze(_, v) = (v.freeze_object!; v)
        def object_methods(_, v, include_super_obj = FTRUE) =
          collect_method_names(v, include_super_obj.truthy?, singleton_only_when_false: true) { |vis| vis != :private }
        def object_public_methods(_, v, include_super_obj = FTRUE) =
          collect_method_names(v, include_super_obj.truthy?) { |vis| vis == :public }
        def object_private_methods(_, v, include_super_obj = FTRUE) =
          collect_method_names(v, include_super_obj.truthy?) { |vis| vis == :private }
        def object_protected_methods(_, v, include_super_obj = FTRUE) =
          collect_method_names(v, include_super_obj.truthy?) { |vis| vis == :protected }

        def object_is_a(_, v, klass)
          # Metaclass hierarchy: #<Class:Foo>.is_a?(#<Class:Bar>) iff Foo.is_a?(Bar's underlying class)
          if v.is_a?(ClassObject) && v.is_singleton_class &&
             klass.is_a?(ClassObject) && klass.is_singleton_class
            sc_of_v = v.singleton_of
            sc_of_k = klass.singleton_of
            if sc_of_v.is_a?(ClassObject) && sc_of_k.is_a?(ClassObject)
              return object_is_a(nil, sc_of_v, sc_of_k)
            end
            # Instance singleton class is_a? class's singleton class iff instance's class <= that class.
            # e.g. instance.singleton_class.is_a?(klass.singleton_class) iff instance.class <= klass
            if !sc_of_v.is_a?(ClassObject) && sc_of_k.is_a?(ClassObject)
              # Check if instance's class is sc_of_k or a subclass of it (walk superclass chain)
              c2 = sc_of_v.class_object
              until c2.nil?
                return FTRUE if c2.ancestors_include?(sc_of_k)
                c2 = c2.is_a?(ClassObject) ? c2.superclass : nil
              end
              return FFALSE
            end
          end
          # A non-singleton class is_a? a singleton class iff the class <= singleton class's singleton_of.
          # e.g. b.is_a?(a.singleton_class) iff b <= a (b is a or a subclass of a).
          if v.is_a?(ClassObject) && !v.is_singleton_class &&
             klass.is_a?(ClassObject) && klass.is_singleton_class
            sc_of_k = klass.singleton_of
            if sc_of_k.is_a?(ClassObject)
              c2 = v
              until c2.nil?
                return FTRUE if c2.ancestors_include?(sc_of_k)
                c2 = c2.is_a?(ClassObject) ? c2.superclass : nil
              end
              return FFALSE
            end
          end
          # Walk from lookup_class (eigenclass if materialised, else class_object).
          # ancestors_include? short-circuits and handles transitive prepend/include at each level.
          c = v.lookup_class
          until c.nil?
            return FTRUE if c.ancestors_include?(klass)
            c = c.is_a?(ClassObject) ? c.superclass : nil
          end
          FFALSE
        end

        def object_ivar_set(_, v, name, value)
          check_frozen!(v)
          v.set_ivar(validated_ivar(name, v), value)
          value
        end

        def ivar_name_error(msg, name_obj, receiver)
          exc = FrozoneException.make(:NameError, msg)
          # Set @name to the original VM object (may be String) for identity equality in tests
          exc.vm_object.set_ivar(:@name, name_obj)
          exc.vm_object.set_ivar(:@receiver, receiver)
          exc
        end

        def object_ivar_remove(_, v, name)
          k = normalize_ivar(name)
          ivars = v.instance_variables_hash
          raise FrozoneException.make(:NameError, "instance variable #{k} not defined") unless ivars&.key?(k)
          ivars.delete(k)
        end

        def object_respond_to(context, v, name, include_private_obj = FFALSE)
          include_private = include_private_obj.truthy?
          if fsym?(name)
            method_name = name.raw
          elsif fstr?(name)
            method_name = name.raw.to_sym
          else
            # Try to_str coercion
            if fobj?(name)
              converted = begin; name.dispatch(context, :to_str, [], {}, nil, private_ok: false); rescue FrozoneException; nil; end
              if fstr?(converted)
                method_name = converted.raw.to_sym
              else
                raise FrozoneException.make(:TypeError, "#{name.class_object&.name || 'Object'} is not a symbol nor a string")
              end
            else
              raise FrozoneException.make(:TypeError, "is not a symbol nor a string")
            end
          end
          # Check active refinements first (refinements can add methods visible to respond_to?)
          active_refinements = context&.frame&.active_refinements
          m = if active_refinements && !active_refinements.empty?
                v.lookup_method_with_refinements(method_name, active_refinements)
              else
                v.lookup_instance_method(method_name)
              end
          # Method is visible if include_private is true, or if it's a public method
          visible = m && (include_private || m.visibility == :public)
          if visible
            FTRUE
          else
            # Method not found or not visible — call respond_to_missing?
            begin
              result = v.dispatch(context, :respond_to_missing?, [name, include_private_obj], {}, nil, private_ok: true)
              result.truthy? ? FTRUE : FFALSE
            rescue FrozoneException
              FFALSE
            end
          end
        end

        def object_dup(context, v)
          # Only works for plain ObjectObject instances — specialized types (String, Array, etc.)
          # define their own dup methods in core Ruby.
          return v unless v.class == ObjectObject
          copy = ObjectObject.allocate
          copy.class_object = v.class_object
          copy.copy_fields_from(v, eigenclass: nil, frozen: false)
          copy.dispatch(context, :initialize_copy, [v], {}, nil, private_ok: true)
          copy
        end

        def module_dup(context, v)
          # BasicObject cannot be duped
          raise FrozoneException.make(:TypeError, "can't copy the root class") if v.equal?(Core::BASIC_OBJECT_CLASS)
          # Create a fresh anonymous module/class and copy the source's contents.
          copy = if v.is_a?(ClassObject)
                   ClassObject.new(nil, v.namespace, v.superclass)
                 else
                   ModuleObject.new(nil, v.namespace, Core::MODULE_CLASS)
                 end
          # Copy methods table (shallow: same Method objects, they're immutable enough)
          v.methods_table.each { |k, meth| copy.methods_table[k] = meth }
          # Copy class variables
          v.class_variables.each { |k, val| copy.class_variables[k] = val }
          # Copy constants
          v.constants_table.each { |k, val| copy.set_constant(k, val) }
          # Copy private-constants set
          v.private_constants_table&.each_key { |k| copy.mark_constant_private(k) }
          # Copy autoload registrations
          v.instance_variable_get(:@autoloads).each do |name, path|
            loc = v.get_autoload_location(name)
            copy.set_autoload(name, path, source_location: loc)
          end
          # Copy prepended/included modules references
          v.prepends.each { |m| copy.prepend_module(m) }
          v.modules.each  { |m| copy.add_module(m) }
          # Copy singleton class (for module/class methods like `def mod.foo`)
          if v.eigenclass
            sc_copy = ClassObject.clone_singleton(v.eigenclass, copy)
            copy.instance_variable_set(:@eigenclass, sc_copy)
          end
          # Call initialize_copy for instance variables
          copy.dispatch(context, :initialize_copy, [v], {}, nil, private_ok: true)
          copy
        end

        def object_clone(context, v, freeze_opt = FNIL)
          # Only works for plain ObjectObject instances — specialized types define their own clone.
          return v unless v.class == ObjectObject
          # Validate freeze: argument — only nil, true, false allowed
          unless fnil?(freeze_opt) || ftrue?(freeze_opt) || ffalse?(freeze_opt)
            type_name = freeze_opt.is_a?(ObjectObject) ? (freeze_opt.class_object&.name || 'Object') : freeze_opt.class.name
            raise FrozoneException.make(:ArgumentError, "unexpected value for freeze: #{type_name}")
          end
          copy = ObjectObject.allocate
          copy.class_object = v.class_object
          sc_copy = v.eigenclass ? ClassObject.clone_singleton(v.eigenclass, copy) : nil
          freeze_val = fnil?(freeze_opt) ? nil : freeze_opt.truthy?
          frozen = freeze_val == false ? false : freeze_val.nil? ? v.frozen_object? : true
          copy.copy_fields_from(v, eigenclass: sc_copy, frozen: false)
          # Call initialize_clone(original, freeze: freeze_opt) — may call initialize_copy
          copy.dispatch(context, :initialize_clone, [v], { freeze: freeze_opt }, nil, private_ok: true)
          copy.freeze_object! if frozen
          copy
        end

        def string_initialize(context, receiver, str_arg, _encoding = FNIL)
          str_val = if fstr?(str_arg)
                      str_arg.raw
                    else
                      begin
                        r = str_arg.dispatch(context, :to_str, [], {})
                        raise FrozoneException.make(:TypeError, "no implicit conversion of #{str_arg.class_object&.name} into String") unless fstr?(r)
                        r.raw
                      rescue FrozoneException => e
                        vm_obj = e.vm_object
                        if vm_obj.is_a?(ObjectObject) && vm_obj.class_object&.name == :NoMethodError
                          raise FrozoneException.make(:TypeError, "no implicit conversion of #{str_arg.class_object&.name} into String")
                        end
                        raise
                      end
                    end
          receiver.raw = str_val.dup
          FNIL
        end

        def string_clone(context, v, freeze_opt = FNIL)
          copy = n2f_str(v.raw.dup)
          copy.class_object = v.class_object
          sc_copy = v.eigenclass ? ClassObject.clone_singleton(v.eigenclass, copy) : nil
          freeze_val = fnil?(freeze_opt) ? nil : freeze_opt.truthy?
          frozen = freeze_val == false ? false : freeze_val.nil? ? v.frozen_object? : true
          copy.copy_fields_from(v, eigenclass: sc_copy, frozen: frozen)
          copy.chilled_source = v.chilled_source unless frozen  # clone preserves chilled status
          copy.dispatch(context, :initialize_copy, [v], {}, nil, private_ok: true)
          copy
        end

        def object_frozen(_, v)
          # Integers, Symbols, nil, true, false are always frozen
          return FTRUE if fint?(v) || fsym?(v) ||
                                     fnil?(v) || ftrue?(v) || ffalse?(v)
          n2f_bool(v.frozen_object?)
        end

        def object_singleton_class(context, v)
          # Integer and Symbol don't have singleton classes
          if fint?(v) || fsym?(v)
            raise FrozoneException.make(:TypeError, "can't define singleton for #{v.class_object.name}")
          end
          # true/false/nil return their class (they are singleton instances)
          if ftrue?(v) || ffalse?(v) || fnil?(v)
            return v.class_object
          end
          if fstr?(v) && v.chilled?
            Frozone::Vm.emit_warning(context, v.chilled_warning)
            v.unchilled!
          end
          v.singleton_class
        end

        def object_eigenclass_has_respond_to_guard(_, v)
          sc = fobj?(v) ? v.eigenclass : nil
          return FFALSE if sc.nil?
          has = sc.get_method(:respond_to?) || sc.get_method(:respond_to_missing?)
          n2f_bool(!has.nil? && has != ModuleObject::UNDEF_SENTINEL)
        end

        def object_singleton_methods(_, v, include_super_obj = FTRUE)
          return n2f_arr([]) if v.eigenclass.nil?
          include_super = include_super_obj.truthy?
          seen = {}
          result = []
          sc = v.singleton_class
          # include_super walk rules differ for classes vs modules/instances:
          # - Classes: walk the full singleton class inheritance (corresponds to superclass chain)
          # - Modules/instances: only include the singleton class itself and modules explicitly
          #   extended into the object (NOT the meta-class chain like #<Class:Module>)
          sources = if include_super
                      if v.is_a?(ClassObject)
                        sc.ancestors_list.take_while { |mod| !mod.is_a?(ClassObject) || mod.is_singleton_class }
                      else
                        # Only sc and explicitly-extended modules (sc.modules and their ancestors, no ClassObjects)
                        explicit_mods = []
                        sc.modules.each { |m| explicit_mods.concat(m.ancestors_list.reject { |a| a.is_a?(ClassObject) }) }
                        [sc] + explicit_mods
                      end
                    else
                      [sc]
                    end
          sources.each do |mod|
            mod.methods_table.each do |name, meth|
              next if seen[name]
              seen[name] = true
              next if meth == ModuleObject::UNDEF_SENTINEL
              next if meth.visibility == :private
              result << n2f_sym(name)
            end
          end
          n2f_arr(result)
        end
      end
    end
  end
end
