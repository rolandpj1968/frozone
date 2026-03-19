# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        ALWAYS_PRIVATE_METHOD_NAMES = %i[initialize initialize_copy initialize_clone initialize_dup respond_to_missing?].freeze

        def module_ruby2_keywords(context, receiver, names_array)
          names_array.raw.each do |name_obj|
            name = sym_name(name_obj)
            m = receiver.is_a?(ClassObject) ? receiver.lookup_method(name) : receiver.get_method(name)
            if m.nil? || m == ModuleObject::UNDEF_SENTINEL
              raise FrozoneException.make(:NameError, "undefined method '#{name}' for class '#{receiver.name}'")
            end
            if m.is_a?(Method)
              has_rest = !m.rest_param.nil?
              has_post = m.post_params && !m.post_params.empty?
              has_kw = !m.required_kw_params.empty? || !m.optional_kw_params.empty? || !m.kw_rest_param.nil?
              if has_rest && !has_post && !has_kw
                m.ruby2_keywords = true
              else
                reason = if !has_rest
                  "does not accept splat"
                elsif has_kw
                  "accepts keyword"
                elsif has_post
                  "accepts post-argument"
                end
                src = m.source_location ? " #{m.source_location}" : ""
                msg = StringObject.new("warning: Skipping set of ruby2_keywords flag for #{name}#{src}: #{reason}")
                kernel_warn(context, NilObject::NIL, ArrayObject.new([msg]))
              end
            elsif m.is_a?(DefinedMethod)
              m.ruby2_keywords = true
            end
          end
          NilObject::NIL
        end

        def module_undef_method(_, receiver, name_obj)
          name = sym_name(name_obj)
          # Check if method exists anywhere in hierarchy
          existing = receiver.is_a?(ClassObject) ? receiver.lookup_method(name) : receiver.get_method(name)
          raise FrozoneException.make(:NameError, "undefined method '#{name}' for class '#{receiver.name}'") if existing.nil?
          receiver.undef_method(name)
          receiver
        end

        def module_undef_methods(context, receiver, names_obj)
          names_obj.raw.each { |name_obj| module_undef_method_dispatch(context, receiver, name_obj) }
          receiver
        end

        def module_remove_methods(context, receiver, names_obj)
          names_obj.raw.each { |name_obj| module_remove_method(context, receiver, name_obj) }
          receiver
        end

        def module_undef_method_dispatch(context, receiver, name_obj)
          name = alias_method_coerce_name(context, name_obj)
          if receiver.frozen_object?
            type_name = receiver.is_a?(ClassObject) ? "Class" : "Module"
            raise FrozoneException.make(:FrozenError, "can't modify frozen #{type_name}: #{receiver.inspect_for_frozen}")
          end
          existing = receiver.is_a?(ClassObject) ? receiver.lookup_method(name) : receiver.get_method(name)
          type_word = receiver.is_a?(ClassObject) ? "class" : "module"
          mod_name = module_display_name(context, receiver)
          raise FrozoneException.make(:NameError, "undefined method '#{name}' for #{type_word} '#{mod_name}'") if existing.nil?
          receiver.undef_method(name)
          trigger_method_undefined(context, receiver, name)
          receiver
        end

        def module_remove_method(context, receiver, name_obj)
          name = alias_method_coerce_name(context, name_obj)
          if receiver.frozen_object?
            type_name = receiver.is_a?(ClassObject) ? "Class" : "Module"
            raise FrozoneException.make(:FrozenError, "can't modify frozen #{type_name}: #{receiver.inspect_for_frozen}")
          end
          m = receiver.get_method(name)
          type_word = receiver.is_a?(ClassObject) ? "class" : "module"
          mod_name = receiver.is_a?(ModuleObject) ? receiver.full_name.to_s : receiver.class.name
          raise FrozoneException.make(:NameError, "method '#{name}' not defined in #{mod_name}") if m.nil?
          receiver.remove_method(name)
          trigger_method_removed(context, receiver, name)
          receiver
        end

        def module_alias_method(context, receiver, new_name_obj, old_name_obj)
          new_name = alias_method_coerce_name(context, new_name_obj)
          old_name = alias_method_coerce_name(context, old_name_obj)
          method = receiver.lookup_method(old_name)
          # Modules may alias methods defined on Object (e.g. Kernel aliasing Object methods)
          method ||= Core::OBJECT_CLASS.lookup_method(old_name) unless receiver.is_a?(ClassObject)
          # Inside a refine block, receiver is the refinement module. If not found there,
          # look in the refined class (e.g. alias_method :x, :count should find Array#count
          # when inside `refine Array do ... end`).
          if method.nil?
            refined_class_obj = receiver.get_ivar(:@__refined_class__)
            if refined_class_obj && !refined_class_obj.is_a?(NilObject)
              method = refined_class_obj.lookup_method(old_name)
            end
          end
          raise FrozoneException.make(:NameError, "undefined method '#{old_name}'") if method.nil?
          aliased = method.alias_as(new_name)
          aliased.visibility = :private if ALWAYS_PRIVATE_METHOD_NAMES.include?(new_name)
          receiver.set_method(new_name, aliased)
          trigger_method_added(context, receiver, new_name)
          SymbolObject.from(new_name)
        end

        def module_define_method(context, receiver, name_obj, block)
          name = alias_method_coerce_name(context, name_obj)
          method = if block.is_a?(UnboundMethodObject)
                     raw = block.raw_method
                     # Validate that the UnboundMethod can be bound to receiver
                     owner = block.unbound_owner
                     if owner && receiver.is_a?(ModuleObject) && !(receiver.is_a?(ClassObject) && receiver.is_singleton_class)
                       # Module owners: any class can define the method (modules are mixin-able to anything)
                       # Class/singleton class owners: receiver must be a subclass/ancestor
                       if owner.is_a?(ClassObject) && owner.is_singleton_class
                         # singleton class owner: can't bind to another class
                         type_name = owner.full_name.to_s
                         raise FrozoneException.make(:TypeError, "can't bind singleton method to a different class")
                       elsif owner.is_a?(ClassObject)
                         # receiver must be owner or a subclass of owner
                         unless receiver.equal?(owner) || receiver.ancestors_include?(owner)
                           type_name = owner.full_name.to_s
                           raise FrozoneException.make(:TypeError, "bind argument must be a subclass of #{type_name}")
                         end
                       end
                       # Pure module owner: no constraint
                     end
                     raw.is_a?(Method) ? raw.bound_copy(name, receiver) : DefinedMethod.new(name, raw.block_obj, receiver)
                   elsif block.is_a?(BoundMethodObject)
                     raw = block.raw_method
                     # Validate: bound method from a singleton class can't be defined on another class
                     bound_owner = block.bound_owner
                     if bound_owner.is_a?(ClassObject) && bound_owner.is_singleton_class
                       raise FrozoneException.make(:TypeError, "can't bind singleton method to a different class")
                     elsif bound_owner.is_a?(ClassObject) && receiver.is_a?(ClassObject)
                       # Check receiver is subclass of the method's defining class
                       unless receiver.ancestors_include?(bound_owner) || bound_owner.ancestors_include?(receiver)
                         raise FrozoneException.make(:TypeError, "bind argument must be a subclass of #{bound_owner.full_name}")
                       end
                     end
                     raw.is_a?(Method) ? raw.bound_copy(name, receiver) : DefinedMethod.new(name, raw.block_obj, receiver)
                   elsif block.is_a?(ProcObject)
                     DefinedMethod.new(name, block.block_object, receiver)
                   elsif block.respond_to?(:invoke)
                     DefinedMethod.new(name, block, receiver)
                   else
                     type_name = block.is_a?(ObjectObject) ? (block.class_object&.name || "Object") : block.class.name
                     raise FrozoneException.make(:TypeError, "wrong argument type #{type_name} (expected Proc/Method/UnboundMethod)")
                   end
          vis = ALWAYS_PRIVATE_METHOD_NAMES.include?(name) ? :private : receiver.current_visibility
          if vis == :module_function
            method.visibility = :private
            receiver.set_method(name, method)
            trigger_method_added(context, receiver, name)
            sm = method.respond_to?(:bound_copy) ? method.bound_copy(name, receiver.singleton_class) : method.dup
            sm.visibility = :public
            receiver.singleton_class.set_method(name, sm)
            trigger_method_added(context, receiver.singleton_class, name)
          else
            method.visibility = vis
            receiver.set_method(name, method)
            trigger_method_added(context, receiver, name)
          end
          SymbolObject.from(name)
        end

        def module_constants(_, receiver, inherit_obj = TrueObject::TRUE)
          inherit = inherit_obj.truthy?
          seen = {}
          result = []
          if inherit
            # Include own constants + prepended/included module constants + superclass constants.
            # Stops before Object/BasicObject (MRI behaviour: ambient top-level constants are
            # not included in a specific class's constants, but Object.constants returns them all
            # because they live in Object's own constants_table).
            collect_consts = lambda do |mod|
              next unless mod.is_a?(ModuleObject)
              mod.prepends.each { |m| collect_consts.call(m) }
              keys = mod.constants_table.keys | mod.instance_variable_get(:@autoloads).keys
              keys.each do |k|
                next if seen[k]
                next if mod.constant_private?(k)
                seen[k] = true
                result << SymbolObject.from(k)
              end
              mod.modules.each { |m| collect_consts.call(m) }
              sup = mod.is_a?(ClassObject) ? mod.superclass : nil
              # Don't recurse into Object or BasicObject — their constants are ambient/top-level
              if sup && !sup.equal?(Core::OBJECT_CLASS) && !sup.equal?(Core::BASIC_OBJECT_CLASS)
                collect_consts.call(sup)
              end
            end
            collect_consts.call(receiver)
          else
            keys = receiver.constants_table.keys | receiver.instance_variable_get(:@autoloads).keys
            keys.each do |k|
              next if receiver.constant_private?(k)
              result << SymbolObject.from(k)
            end
          end
          ArrayObject.new(result)
        end

        CVAR_NAME_RE = /\A@@[^@!? ][^!? ]*\z/.freeze

        def validate_cvar_name!(name_str, name_obj, receiver: nil)
          unless name_str.start_with?('@@') && name_str.length > 2 && name_str[2] != '@'
            exc = FrozoneException.make(:NameError, "`#{name_str}' is not allowed as a class variable name")
            exc.vm_object.set_ivar(:@name, name_obj)
            exc.vm_object.set_ivar(:@receiver, receiver) if receiver
            raise exc
          end
        end

        def coerce_cvar_name(context, name_obj)
          if name_obj.is_a?(SymbolObject)
            name_obj.raw.to_s
          elsif name_obj.is_a?(StringObject)
            name_obj.raw
          else
            # Try to_str
            has_to_str = begin
              name_obj.dispatch(context, :respond_to?, [SymbolObject.from(:to_str)], {}).truthy?
            rescue FrozoneException
              false
            end
            unless has_to_str
              type_name = name_obj.is_a?(ObjectObject) ? (name_obj.class_object&.name || "Object") : name_obj.class.name
              raise FrozoneException.make(:TypeError, "#{type_name} is not a symbol nor a string")
            end
            result = name_obj.dispatch(context, :to_str, [], {})
            raise FrozoneException.make(:TypeError, "to_str must return String") unless result.is_a?(StringObject)
            result.raw
          end
        end

        def class_var_defined_in_ancestors?(receiver, name)
          # Also check the eigenclass (singleton class) for class variables set inside `class << self`
          return true if receiver.eigenclass&.class_variables&.key?(name)
          ancestors = receiver.respond_to?(:ancestors_list) ? receiver.ancestors_list : [receiver]
          ancestors.any? { |a| a.class_variables.key?(name) }
        end

        def get_class_var_from_ancestors(receiver, name)
          return receiver.eigenclass.class_variables[name] if receiver.eigenclass&.class_variables&.key?(name)
          ancestors = receiver.respond_to?(:ancestors_list) ? receiver.ancestors_list : [receiver]
          ancestors.each do |a|
            return a.class_variables[name] if a.class_variables.key?(name)
          end
          nil
        end

        def module_class_variable_defined(context, receiver, name_obj)
          name_str = coerce_cvar_name(context, name_obj)
          validate_cvar_name!(name_str, name_obj)
          name = name_str.to_sym
          class_var_defined_in_ancestors?(receiver, name) ? TrueObject::TRUE : FalseObject::FALSE
        end

        def module_class_variables(_, receiver, inherit_obj = TrueObject::TRUE)
          inherit = inherit_obj.truthy?
          seen = {}
          if inherit
            # Collect from eigenclass, this class, and superclass chain
            receiver.eigenclass&.class_variables&.each_key { |k| seen[k] = true }
            c = receiver
            while c
              c.class_variables.each_key { |k| seen[k] = true }
              c = c.is_a?(ClassObject) ? c.superclass : nil
            end
          else
            # Only this class's own class variables (+ eigenclass for singleton objects)
            receiver.eigenclass&.class_variables&.each_key { |k| seen[k] = true }
            receiver.class_variables.each_key { |k| seen[k] = true }
          end
          ArrayObject.new(seen.keys.map { |k| SymbolObject.from(k) })
        end

        def module_class_variable_get(context, receiver, name_obj)
          name_str = coerce_cvar_name(context, name_obj)
          validate_cvar_name!(name_str, name_obj, receiver: receiver)
          name = name_str.to_sym
          val = get_class_var_from_ancestors(receiver, name)
          if val.nil?
            exc = FrozoneException.make(:NameError, "uninitialized class variable #{name} in #{receiver.name || '#<Module>'}")
            exc.vm_object.set_ivar(:@name, SymbolObject.from(name))
            exc.vm_object.set_ivar(:@receiver, receiver)
            raise exc
          end
          val
        end

        def module_class_variable_set(context, receiver, name_obj, value)
          name_str = coerce_cvar_name(context, name_obj)
          validate_cvar_name!(name_str, name_obj)
          name = name_str.to_sym
          if receiver.is_a?(ObjectObject) && receiver.frozen_object?
            raise FrozoneException.make(:FrozenError, "can't modify frozen #{receiver.class_object&.name || 'Object'}: #{receiver.inspect rescue '?'}")
          end
          receiver.set_class_var(name, value)
          value
        end

        def module_private_constant(context, receiver, *name_objs)
          name_objs.each do |name_obj|
            name = sym_name_coercing(context, name_obj)
            raise FrozoneException.make(:NameError, "constant #{receiver.full_name}::#{name} not defined") if receiver.get_constant(name).nil? && receiver.get_autoload(name).nil?
            receiver.mark_constant_private(name)
          end
          receiver
        end

        def module_public_constant(context, receiver, *name_objs)
          name_objs.each do |name_obj|
            name = sym_name_coercing(context, name_obj)
            raise FrozoneException.make(:NameError, "constant #{receiver.full_name}::#{name} not defined") if receiver.get_constant(name).nil? && receiver.get_autoload(name).nil?
            receiver.private_constants_table&.delete(name)
          end
          receiver
        end

        def module_remove_const(context, receiver, name_obj)
          name = sym_name_coercing(context, name_obj)
          val = receiver.get_constant(name)
          if val.nil?
            # Check if it's an autoload registration
            if receiver.get_autoload(name)
              receiver.remove_autoload(name)
              return NilObject::NIL
            end
            raise FrozoneException.make(:NameError, "constant #{name} not defined")
          end
          maybe_warn_deprecated_constant(context, receiver, name)
          receiver.constants_table.delete(name)
          val
        end

        def module_remove_class_variable(_, receiver, name_obj)
          name = sym_name(name_obj)
          raise FrozoneException.make(:NameError, "class variable #{name} not defined for #{receiver.name}") unless receiver.class_variables.key?(name)
          receiver.class_variables.delete(name) || NilObject::NIL
        end

        def module_name(_, receiver)
          if receiver.instance_variable_defined?(:@temporary_name)
            temp = receiver.instance_variable_get(:@temporary_name)
            if temp
              # Cached temp name string — keyed by temp string value
              cached = receiver.instance_variable_get(:@cached_name_str)
              return cached if cached&.raw == temp
              s = StringObject.new(temp)
              receiver.instance_variable_set(:@cached_name_str, s)
              return s
            end
          end
          return NilObject::NIL unless receiver.name
          # Cache the name string for identity stability
          full = receiver.full_name.to_s
          cached = receiver.instance_variable_get(:@cached_name_str)
          return cached if cached&.raw == full
          s = StringObject.new(full)
          receiver.instance_variable_set(:@cached_name_str, s)
          s
        end

        def module_singleton_class_q(_, receiver) = receiver.is_a?(ClassObject) && receiver.is_singleton_class ? TrueObject::TRUE : FalseObject::FALSE

        def module_using(context, _receiver, mod)
          raise FrozoneException.make(:TypeError, "wrong argument type #{frozone_class_name(mod)} (expected Module)") unless mod.is_a?(ModuleObject)
          raise FrozoneException.make(:TypeError, "wrong argument type Class (expected Module)") if mod.is_a?(ClassObject)
          caller_frame = context.frame.parent_frame
          raise FrozoneException.make(:RuntimeError, "Module#using is not permitted in methods") if caller_frame&.method_frame&.current_method
          new_refs = collect_refinements_from_module(mod)
          unless new_refs.empty?
            target_frame = caller_frame
            target_frame.active_refinements ||= {}
            target_frame.active_refinements.merge!(new_refs)
          end
          NilObject::NIL
        end

        def module_used_refinements(context, _klass)
          # used_refinements returns refinements active in the CALLING scope.
          # When called as an intrinsic, context.frame is the module body frame itself.
          # When called via a method wrapper, context.frame is the method frame and
          # context.frame.parent_frame is the module body frame.
          # Check both: current frame and its parent.
          frame = context.frame
          refs = frame&.active_refinements
          if (refs.nil? || refs.empty?) && frame
            refs = frame.parent_frame&.active_refinements
          end
          return ArrayObject.new([]) unless refs && !refs.empty?
          ArrayObject.new(refs.values)
        end

        # Evaluate a refine block with all the refining module's own refinements active.
        # This enables cross-refinement calls inside the refine block.
        def module_refine_eval(context, refining_mod, refinement_mod, block)
          # Collect the refining module's own refinements (NOT ancestors), using Frozone's get_ivar
          own_refs_obj = refining_mod.get_ivar(:@__refinements__)
          own_refs = {}
          unless own_refs_obj.is_a?(NilObject) || !own_refs_obj.is_a?(HashObject)
            own_refs_obj.raw.each do |k, v|
              key = k.is_a?(IntegerObject) ? k.raw : k
              own_refs[key] = v if v.is_a?(ModuleObject)
            end
          end
          # Also include the refinement_mod itself (for the class being refined)
          refined_class_obj = refinement_mod.get_ivar(:@__refined_class__)
          refined_class = refined_class_obj.is_a?(NilObject) ? nil : refined_class_obj
          all_refs = own_refs.dup
          all_refs[refined_class.object_id] = refinement_mod if refined_class

          block_obj = block.is_a?(BlockObject) ? block : (block.is_a?(ProcObject) ? block.block_object : block)
          unless block_obj.is_a?(BlockObject)
            module_eval(context, refinement_mod, block)
            return NilObject::NIL
          end

          # Temporarily install refinements and refining_module on the block's enclosing frame.
          # BlockObject#invoke creates a new_frame inheriting active_refinements and
          # current_refining_module from enclosing_frame, so setting them here makes them
          # visible inside the refine block body (for cross-refinement and method.refining_module).
          enc_frame = block_obj.enclosing_frame
          prev_enc_refs = enc_frame.active_refinements
          prev_enc_refining_mod = enc_frame.current_refining_module
          enc_frame.active_refinements = if all_refs.empty?
            prev_enc_refs
          elsif prev_enc_refs
            prev_enc_refs.merge(all_refs)
          else
            all_refs
          end
          enc_frame.current_refining_module = refining_mod
          begin
            module_eval(context, refinement_mod, block)
          ensure
            enc_frame.active_refinements = prev_enc_refs
            enc_frame.current_refining_module = prev_enc_refining_mod
          end
          NilObject::NIL
        end

        def module_set_temporary_name(_, receiver, name_obj)
          # Compute at runtime whether this module has a permanent name
          is_permanent = if receiver.name
            c = receiver
            all_named = true
            while c && !c.equal?(Core::OBJECT_CLASS)
              unless c.name
                all_named = false
                break
              end
              c = c.namespace
            end
            all_named
          else
            false
          end
          if name_obj.is_a?(NilObject)
            raise FrozoneException.make(:RuntimeError, "can't change permanent name") if is_permanent
            receiver.instance_variable_set(:@temporary_name, nil)
            receiver.clear_name! unless is_permanent
            return receiver
          end
          raise FrozoneException.make(:TypeError, "#{frozone_class_name(name_obj)} is not a String") unless name_obj.is_a?(StringObject)
          name_s = name_obj.raw
          raise FrozoneException.make(:ArgumentError, "empty class/module name") if name_s.empty?
          # Reject valid constant paths: all :: components are valid constant names
          if name_s.start_with?("::")
            raise FrozoneException.make(:ArgumentError, "the temporary name must not be a constant path to avoid confusion")
          end
          parts = name_s.split("::", -1)
          if parts.all? { |p| p =~ /\A[A-Z][a-zA-Z0-9_]*\z/ }
            raise FrozoneException.make(:ArgumentError, "the temporary name must not be a constant path to avoid confusion")
          end
          raise FrozoneException.make(:RuntimeError, "can't change permanent name") if is_permanent
          receiver.instance_variable_set(:@temporary_name, name_s)
          receiver.instance_variable_set(:@cached_name_str, nil)
          receiver
        end

        CONST_NAME_RE = /\A[A-Z\p{Lu}][\p{L}\p{N}_]*\z/u.freeze

        def validate_const_name!(name_s, orig_name_obj)
          orig_s = orig_name_obj.is_a?(SymbolObject) ? orig_name_obj.raw.to_s : (orig_name_obj.is_a?(StringObject) ? orig_name_obj.raw : name_s)
          # Encode to UTF-8 for Unicode regex matching (handles EUC-JP etc.)
          check_s = name_s.encoding == Encoding::UTF_8 ? name_s : name_s.encode("UTF-8", invalid: :replace, undef: :replace)
          raise FrozoneException.make(:NameError, "wrong constant name #{orig_s}") unless check_s =~ CONST_NAME_RE
        end

        def resolve_const_path(context, name_obj, receiver, inherit)
          is_symbol = name_obj.is_a?(SymbolObject)
          name_str = if is_symbol
            name_obj.raw.to_s
          elsif name_obj.is_a?(StringObject)
            name_obj.raw
          else
            r = sym_name_coercing(context, name_obj)
            r.to_s
          end
          # Symbols must be simple constant names — no :: allowed
          if is_symbol && (name_str.include?("::") || name_str.empty?)
            raise FrozoneException.make(:NameError, "wrong constant name #{name_str.inspect}")
          end
          # Handle :: prefix (absolute path) — only valid for Strings
          start = receiver
          remaining = name_str
          if remaining.start_with?("::")
            start = Core::OBJECT_CLASS
            remaining = remaining[2..]
          end
          # Split on ::
          parts = remaining.split("::", -1)
          # '::' alone (or leading :: with empty remainder) should raise NameError
          if parts.empty? || parts.any?(&:empty?)
            orig_s = name_obj.is_a?(SymbolObject) ? name_obj.raw.to_s : (name_obj.is_a?(StringObject) ? name_obj.raw : remaining)
            raise FrozoneException.make(:NameError, "wrong constant name #{orig_s}")
          end
          [start, parts]
        end

        def module_const_defined(context, receiver, name_obj, inherit = TrueObject::TRUE)
          inherit_b = inherit.is_a?(FalseObject) || inherit.equal?(NilObject::NIL) ? false : true
          start, parts = resolve_const_path(context, name_obj, receiver, inherit_b)
          parts.each_with_index do |part, i|
            validate_const_name!(part, name_obj)
            sym = part.to_sym
            last = (i == parts.size - 1)
            if last
              c = if inherit_b
                val, = start.lookup_constant_with_owner(sym)
                # Fall through to Object only if receiver inherits from Object
                # (BasicObject subclasses should NOT see Object constants)
                object_visible = !start.equal?(Core::OBJECT_CLASS) &&
                  (!start.is_a?(ClassObject) || start.ancestors_list.any? { |a| a.equal?(Core::OBJECT_CLASS) })
                val || (object_visible && Core::OBJECT_CLASS.lookup_constant(sym)) ||
                  start.lookup_autoload(sym, inherit: true)
              else
                start.get_constant(sym) || start.get_autoload(sym)
              end
              # An autoload path that is already in $LOADED_FEATURES is not considered defined
              if c.is_a?(::String)
                resolved = resolve_load_path(c)
                c = nil if resolved && GLOBALS[:"$LOADED_FEATURES"].raw.any? { |s| s.raw == resolved }
              end
              return !c.nil? && c != false ? TrueObject::TRUE : FalseObject::FALSE
            else
              # For non-last parts: inherit=false means only search own constants
              val = if inherit_b
                v, = start.lookup_constant_with_owner(sym)
                v
              else
                start.get_constant(sym)
              end
              return FalseObject::FALSE if val.nil?
              return FalseObject::FALSE unless val.is_a?(ModuleObject)
              start = val
            end
          end
          FalseObject::FALSE
        end

        def module_const_get(context, receiver, name_obj, inherit = TrueObject::TRUE)
          inherit_b = inherit.is_a?(FalseObject) || inherit.equal?(NilObject::NIL) ? false : true
          start, parts = resolve_const_path(context, name_obj, receiver, inherit_b)
          orig_name_obj = name_obj
          scoped = parts.size > 1  # multi-component path like A::B
          parts.each_with_index do |part, i|
            validate_const_name!(part, orig_name_obj)
            sym = part.to_sym
            last = (i == parts.size - 1)
            if last
              c = if !inherit_b
                # inherit=false: only own constants
                start.get_constant(sym)
              elsif !scoped
                # Simple lookup: walk own + included modules, then also search Object for toplevel constants
                start.lookup_constant(sym) ||
                  (!start.equal?(Core::OBJECT_CLASS) && Core::OBJECT_CLASS.lookup_constant(sym))
              else
                # Scoped path (A::B): only search start's hierarchy, NOT Object
                start.lookup_constant(sym)
              end
              if !c || c.equal?(false)
                # Check for autoload before const_missing
                autoload_path = start.lookup_autoload(sym, inherit: inherit_b)
                autoload_path ||= (!inherit_b ? nil : (!start.equal?(Core::OBJECT_CLASS) && Core::OBJECT_CLASS.lookup_autoload(sym, inherit: true)))
                if autoload_path
                  begin
                    kernel_require(context, nil, StringObject.new(autoload_path))
                  rescue FrozoneException, StandardError
                    # If require fails, fall through to const_missing
                  end
                  c = if !inherit_b
                    start.get_constant(sym)
                  elsif !scoped
                    start.lookup_constant(sym) || (!start.equal?(Core::OBJECT_CLASS) && Core::OBJECT_CLASS.lookup_constant(sym))
                  else
                    start.lookup_constant(sym)
                  end
                end
                return start.dispatch(context, :const_missing, [SymbolObject.from(sym)], {}, nil, private_ok: true) if !c || c.equal?(false)
              end
              _, owner = start.lookup_constant_with_owner(sym)
              maybe_warn_deprecated_constant(context, owner, sym)
              return c
            else
              c = start.lookup_constant(sym)
              # For non-last parts of a scoped name, also fall back to Object (top-level constants)
              c ||= Core::OBJECT_CLASS.lookup_constant(sym) unless start.equal?(Core::OBJECT_CLASS)
              if c.nil?
                # Check autoload for intermediate path components
                autoload_path = start.lookup_autoload(sym, inherit: true)
                autoload_path ||= Core::OBJECT_CLASS.lookup_autoload(sym, inherit: true) unless start.equal?(Core::OBJECT_CLASS)
                if autoload_path
                  begin
                    kernel_require(context, nil, StringObject.new(autoload_path))
                    c = start.lookup_constant(sym)
                    c ||= Core::OBJECT_CLASS.lookup_constant(sym) unless start.equal?(Core::OBJECT_CLASS)
                  rescue FrozoneException, StandardError
                    # fall through to const_missing
                  end
                end
                return start.dispatch(context, :const_missing, [SymbolObject.from(sym)], {}) if c.nil?
              end
              raise FrozoneException.make(:TypeError, "#{part} is not a module") unless c.is_a?(ModuleObject)
              start = c
            end
          end
          NilObject::NIL
        end

        def module_const_source_location(context, receiver, name_obj, inherit_obj = TrueObject::TRUE)
          inherit_b = inherit_obj.truthy?
          start, parts = resolve_const_path(context, name_obj, receiver, inherit_b)
          scoped = parts.size > 1

          # Walk all non-last parts
          parts[0..-2].each do |part|
            validate_const_name!(part, name_obj)
            sym = part.to_sym
            c = start.lookup_constant(sym)
            c ||= Core::OBJECT_CLASS.lookup_constant(sym) unless start.equal?(Core::OBJECT_CLASS)
            return NilObject::NIL unless c.is_a?(ModuleObject)
            start = c
          end

          last_part = parts.last
          validate_const_name!(last_part, name_obj)
          name = last_part.to_sym

          # Build search chain
          search_chain = if inherit_b && !scoped
            result = []
            seen = {}
            walk = lambda do |mod|
              next unless mod.is_a?(ModuleObject)
              next if seen[mod.object_id]
              seen[mod.object_id] = true
              mod.prepends.each { |m| walk.call(m) }
              result << mod
              mod.modules.each { |m| walk.call(m) }
              sup = mod.is_a?(ClassObject) ? mod.superclass : nil
              walk.call(sup) if sup
            end
            walk.call(start)
            walk.call(Core::OBJECT_CLASS) unless seen[Core::OBJECT_CLASS.object_id]
            result
          else
            [start]
          end

          search_chain.each do |mod|
            # Check autoload first (constant not yet loaded)
            if mod.get_autoload(name)
              loc = mod.get_autoload_location(name)
              if loc
                return ArrayObject.new([StringObject.new(loc[0]), IntegerObject.new(loc[1])])
              else
                return ArrayObject.new([])
              end
            end
            next unless mod.constants_table.key?(name)
            loc = mod.get_constant_location(name)
            if loc
              return ArrayObject.new([StringObject.new(loc[0]), IntegerObject.new(loc[1])])
            else
              return ArrayObject.new([])
            end
          end
          NilObject::NIL
        end

        def module_autoload(context, receiver, name_obj, path_obj)
          raise FrozoneException.make(:FrozenError, "can't modify frozen #{frozone_class_name(receiver)}: #{receiver.full_name}") if receiver.frozen_object?
          name = sym_name(name_obj)
          path = if path_obj.is_a?(StringObject)
            path_obj.raw
          else
            to_path_result = begin
              r = path_obj.dispatch(context, :to_path, [], {})
              r.is_a?(StringObject) ? r.raw : nil
            rescue FrozoneException
              nil
            end
            if to_path_result
              to_path_result
            else
              begin
                r2 = path_obj.dispatch(context, :to_str, [], {})
                raise FrozoneException.make(:TypeError, "no implicit conversion of #{frozone_class_name(path_obj)} into String") unless r2.is_a?(StringObject)
                r2.raw
              rescue FrozoneException => e
                raise if e.frozone_class_name == :TypeError
                raise FrozoneException.make(:TypeError, "no implicit conversion of #{frozone_class_name(path_obj)} into String")
              end
            end
          end
          raise FrozoneException.make(:ArgumentError, "empty file name") if path.empty?
          unless name.to_s =~ /\A[A-Z][a-zA-Z0-9_]*\z/
            raise FrozoneException.make(:NameError, "wrong constant name #{name}")
          end
          src_loc = context.call_site ? context.call_site.split(':').then { |parts| parts.length >= 2 ? [parts[0..-2].join(':'), parts[-1].to_i] : nil } : nil
          receiver.set_autoload(name, path, source_location: src_loc)
          Frozone::Vm.trigger_const_added(context, receiver, name)
          NilObject::NIL
        end

        def module_autoload_q(context, receiver, name_obj, inherit_obj = TrueObject::TRUE)
          name = sym_name(name_obj)
          inherit = inherit_obj.truthy?
          path = receiver.lookup_autoload(name, inherit: inherit)
          return NilObject::NIL unless path
          # Return nil if file is already in $LOADED_FEATURES (treated as already loaded)
          loaded = GLOBALS[:"$LOADED_FEATURES"]
          resolved = resolve_load_path(path)
          return NilObject::NIL if resolved && loaded.raw.any? { |s| s.raw == resolved }
          StringObject.new(path)
        end

        def module_const_set(context, receiver, name_obj, value)
          raise FrozoneException.make(:FrozenError, "can't modify frozen #{frozone_class_name(receiver)}: #{receiver.full_name}") if receiver.frozen_object?
          # Try to_str coercion for non-Symbol/String name
          name_obj = if name_obj.is_a?(SymbolObject) || name_obj.is_a?(StringObject)
            name_obj
          else
            coerced = begin
              name_obj.dispatch(context, :to_str, [], {})
            rescue FrozoneException
              raise FrozoneException.make(:TypeError, "#{frozone_class_name(name_obj)} is not a symbol nor a string")
            end
            raise FrozoneException.make(:TypeError, "can't convert #{frozone_class_name(name_obj)} into String (to_str gives #{frozone_class_name(coerced)})") unless coerced.is_a?(StringObject)
            coerced
          end
          name = sym_name(name_obj)
          name_s = name.to_s
          check_s = name_s.encoding == Encoding::UTF_8 ? name_s : name_s.encode("UTF-8", invalid: :replace, undef: :replace)
          raise FrozoneException.make(:NameError, "wrong constant name #{name_s}") unless check_s =~ CONST_NAME_RE
          emit_vm_warning(context, "already initialized constant #{receiver.name}::#{name}") if receiver.get_constant(name)
          # Use call_site as source location for dynamically set constants
          src_loc = context.call_site ? context.call_site.split(':').then { |parts| parts.length >= 2 ? [parts[0..-2].join(':'), parts[-1].to_i] : nil } : nil
          receiver.set_constant(name, value, source_location: src_loc)
          # Auto-name anonymous classes/modules (same as constant_write.rb)
          if value.is_a?(ModuleObject) && (value.name.nil? || !value.name_permanent)
            container_permanent = receiver.equal?(Core::OBJECT_CLASS) || receiver.name_permanent
            if value.name.nil? || container_permanent
              value.set_name(name)
              value.namespace = receiver.equal?(Core::OBJECT_CLASS) ? nil : receiver
              value.instance_variable_set(:@temporary_name, nil) if value.instance_variable_defined?(:@temporary_name)
              value.mark_name_permanent! if container_permanent
            end
          end
          Frozone::Vm.trigger_const_added(context, receiver, name)
          value
        end

        def module_eval(context, receiver, block)
          return NilObject::NIL if block.is_a?(NilObject)
          prev_vis = receiver.is_a?(ModuleObject) ? receiver.current_visibility : nil
          receiver.current_visibility = :public if prev_vis
          context.scopes << receiver
          begin
            block.invoke(context, [receiver], receiver: receiver, def_scope: receiver)
          ensure
            context.scopes.pop
            receiver.current_visibility = prev_vis if prev_vis
          end
        end

        def module_exec(context, receiver, args_obj, block)
          return NilObject::NIL if block.is_a?(NilObject)
          args = args_obj.is_a?(ArrayObject) ? args_obj.raw : []
          prev_vis = receiver.is_a?(ModuleObject) ? receiver.current_visibility : nil
          receiver.current_visibility = :public if prev_vis
          context.scopes << receiver
          begin
            block.invoke(context, args, receiver: receiver, def_scope: receiver)
          ensure
            context.scopes.pop
            receiver.current_visibility = prev_vis if prev_vis
          end
        end

        def module_eval_string(context, receiver, code_obj, file_obj = NilObject::NIL, line_obj = NilObject::NIL)
          code = code_obj.is_a?(StringObject) ? code_obj.raw : code_obj.to_s
          file = file_obj.is_a?(StringObject) ? file_obj.raw : nil
          line = line_obj.is_a?(IntegerObject) ? line_obj.raw : nil
          # Build caller location string if no file given
          file ||= (context.call_site ? "(eval at #{context.call_site})" : "(eval)")
          line ||= 1
          parser = Parser.new(code, filepath: file, line: line)
          ast = parser.ast
          # Evaluate in a frame where self = receiver (the module/class)
          # Reset current_visibility to :public for the eval context (like class body)
          prev_vis = receiver.is_a?(ModuleObject) ? receiver.current_visibility : nil
          receiver.current_visibility = :public if prev_vis
          # Build scope chain from receiver's namespace nesting (innermost last),
          # so constant lookup sees the receiver's enclosing namespaces.
          eval_scopes = [Core::OBJECT_CLASS]
          if receiver.is_a?(ModuleObject)
            chain = []
            ns = receiver
            while ns.is_a?(ModuleObject) && !ns.equal?(Core::OBJECT_CLASS)
              chain.unshift(ns)
              ns = ns.namespace
            end
            chain.each { |m| eval_scopes << m unless eval_scopes.include?(m) }
          end
          new_frame = Frame.new(receiver, parser.top_level_locals, eval_scopes)
          # Inherit active refinements from the calling frame (lexical scope for eval)
          new_frame.active_refinements = context.frame.active_refinements if context.frame&.active_refinements
          context.push_frame(new_frame)
          context.scopes << receiver
          begin
            ast.evaluate(context)
          ensure
            context.pop_frame
            context.scopes.pop
            receiver.current_visibility = prev_vis if prev_vis
          end
        end

        def module_nesting(context, _receiver)
          # Return the lexical nesting: use the calling frame's scopes (method definition site),
          # falling back to context.scopes for top-level calls.
          # For method frames (def self.foo style), singleton classes are appended at the end
          # for super lookup but are NOT part of the lexical nesting — filter them out.
          # For class body frames (class << self), singleton classes ARE part of the nesting.
          frame = context.frames.length >= 2 ? context.frames[-2] : context.frame
          scopes = frame.scopes
          if frame.method_frame.equal?(frame)
            # Method invocation frame: filter out singleton classes (added for super, not nesting)
            scopes = scopes.reject { |s| s.is_a?(ClassObject) && s.is_singleton_class }
          end
          lex = (!scopes.empty? && scopes[0].equal?(Core::OBJECT_CLASS)) ? scopes[1..] : scopes
          ArrayObject.new(lex.reverse)
        end

        def module_ancestors(_, receiver)
          result = []
          walk = lambda do |mod|
            mod.prepends.each { |m| walk.call(m) }
            result << mod
            mod.modules.each { |m| walk.call(m) }
            if mod.is_a?(ClassObject) && mod.superclass
              walk.call(mod.superclass)
            end
          end
          walk.call(receiver)
          ArrayObject.new(result)
        end

        def module_instance_methods(_, receiver, include_super_obj = TrueObject::TRUE, vis_filter = NilObject::NIL)
          include_super = include_super_obj.truthy?
          seen = {}
          result = []
          collect = lambda do |mod|
            mod.methods_table.each do |name, m|
              next if seen[name]
              seen[name] = true
              next if m == ModuleObject::UNDEF_SENTINEL
              next if vis_filter && m.visibility != vis_filter
              result << SymbolObject.from(name) if m.visibility == :public || m.visibility == :protected
            end
          end
          walk = lambda do |mod|
            mod.prepends.each { |m| walk.call(m) }
            collect.call(mod)
            mod.modules.each { |m| walk.call(m) }
            walk.call(mod.superclass) if mod.is_a?(ClassObject) && mod.superclass
          end
          if include_super
            walk.call(receiver)
          else
            collect.call(receiver)
          end
          # For refinement modules: include the refined class's instance methods.
          # MRI's Refinement#instance_methods returns methods including those of the refined module.
          refined_class_obj = receiver.get_ivar(:@__refined_class__)
          if refined_class_obj && !refined_class_obj.is_a?(NilObject)
            walk.call(refined_class_obj)
          end
          ArrayObject.new(result)
        end

        def module_public_only_instance_methods(ctx, receiver, include_super_obj = TrueObject::TRUE) = module_instance_methods(ctx, receiver, include_super_obj, :public)

        def module_undefined_instance_methods(_, receiver)
          result = []
          receiver.methods_table.each do |name, m|
            result << SymbolObject.from(name) if m == ModuleObject::UNDEF_SENTINEL
          end
          ArrayObject.new(result)
        end

        def module_method_defined(context, receiver, name_obj, inherit_obj = TrueObject::TRUE)
          name = sym_name_coercing(context, name_obj)
          inherit = inherit_obj.truthy?
          m = inherit ? receiver.lookup_method(name) : receiver.get_method(name)
          m && m != ModuleObject::UNDEF_SENTINEL && (m.visibility == :public || m.visibility == :protected) ? TrueObject::TRUE : FalseObject::FALSE
        end

        def module_private_instance_methods(_, receiver, include_super_obj = TrueObject::TRUE)
          include_super = include_super_obj.truthy?
          seen = {}
          result = []
          collect = lambda do |mod|
            mod.methods_table.each do |name, m|
              next if seen[name]
              seen[name] = true
              next if m == ModuleObject::UNDEF_SENTINEL
              result << SymbolObject.from(name) if m.visibility == :private
            end
          end
          if include_super
            walk = lambda do |mod|
              mod.prepends.each { |m| walk.call(m) }
              collect.call(mod)
              mod.modules.each { |m| walk.call(m) }
              walk.call(mod.superclass) if mod.is_a?(ClassObject) && mod.superclass
            end
            walk.call(receiver)
          else
            collect.call(receiver)
          end
          ArrayObject.new(result)
        end

        def module_protected_instance_methods(_, receiver, include_super_obj = TrueObject::TRUE)
          include_super = include_super_obj.truthy?
          seen = {}
          result = []
          collect = lambda do |mod|
            mod.methods_table.each do |name, m|
              next if seen[name]
              seen[name] = true
              next if m == ModuleObject::UNDEF_SENTINEL
              result << SymbolObject.from(name) if m.visibility == :protected
            end
          end
          if include_super
            walk = lambda do |mod|
              mod.prepends.each { |m| walk.call(m) }
              collect.call(mod)
              mod.modules.each { |m| walk.call(m) }
              walk.call(mod.superclass) if mod.is_a?(ClassObject) && mod.superclass
            end
            walk.call(receiver)
          else
            collect.call(receiver)
          end
          ArrayObject.new(result)
        end

        def module_instance_method(context, receiver, name_obj)
          name = sym_name_coercing(context, name_obj)
          # Check active refinements first (refinements shadow regular methods for instance_method).
          # Refinements active at the CALL SITE take priority — the method itself (instance_method)
          # has no stored refinements, so check the caller's frame (parent_frame) for using-activated refinements.
          active_refs = caller_active_refinements(context)
          if active_refs && !active_refs.empty?
            receiver.ancestors_list.each do |ancestor|
              ref_mod = active_refs[ancestor.object_id]
              if ref_mod
                ref_m = ref_mod.get_method(name)
                if ref_m && ref_m != ModuleObject::UNDEF_SENTINEL
                  owner = ref_m.is_a?(Method) && ref_m.original_owner ? ref_m.original_owner : ref_mod
                  return UnboundMethodObject.new(ref_m, name, owner)
                end
              end
            end
          end
          m = receiver.lookup_method(name)
          if m.nil? || m == ModuleObject::UNDEF_SENTINEL
            exc = FrozoneException.make(:NameError, "undefined method '#{name}' for class '#{receiver.name}'")
            exc.vm_object.set_ivar(:@name, SymbolObject.from(name))
            raise exc
          end
          owner = receiver.lookup_method_owner(name) || receiver
          UnboundMethodObject.new(m, name, owner)
        end

        def module_public_instance_method(context, receiver, name_obj)
          name = sym_name_coercing(context, name_obj)
          m = receiver.lookup_method(name)
          if m.nil? || m == ModuleObject::UNDEF_SENTINEL
            exc = FrozoneException.make(:NameError, "undefined method '#{name}' for class '#{receiver.name}'")
            exc.vm_object.set_ivar(:@name, SymbolObject.from(name))
            raise exc
          end
          unless m.visibility == :public
            exc = FrozoneException.make(:NameError, "method '#{name}' for class '#{receiver.name}' is #{m.visibility}")
            exc.vm_object.set_ivar(:@name, SymbolObject.from(name))
            raise exc
          end
          owner = receiver.lookup_method_owner(name) || receiver
          UnboundMethodObject.new(m, name, owner)
        end

        def object_method(context, receiver, name_obj)
          name = sym_name_coercing(context, name_obj)
          # Check active refinements first — `method(:foo)` with refinements active should find refined methods
          active_refinements = context&.frame&.active_refinements
          m = if active_refinements && !active_refinements.empty?
            receiver.lookup_method_with_refinements(name, active_refinements)
          else
            klass = receiver.eigenclass || receiver.class_object
            klass.lookup_method(name) || receiver.class_object.lookup_method(name)
          end
          unless m
            # Check respond_to_missing?
            rtm = begin
              receiver.dispatch(context, :respond_to_missing?, [SymbolObject.from(name), TrueObject::TRUE], {}, nil, private_ok: true)
            rescue FrozoneException
              FalseObject::FALSE
            end
            if rtm.truthy?
              owner = receiver.class_object
              bm = BoundMethodObject.new(nil, name, receiver, owner)
              bm.method_missing_dispatch = true
              return bm
            end
            raise FrozoneException.make(:NameError, "undefined method '#{name}' for class '#{receiver.class_object.full_name}'")
          end
          # If the eigenclass has the method (directly or via extended modules), use eigenclass chain for owner
          if receiver.eigenclass&.lookup_method(name)
            owner = receiver.eigenclass.lookup_method_owner(name) || receiver.eigenclass
          else
            owner = receiver.class_object.lookup_method_owner(name) || receiver.class_object
          end
          BoundMethodObject.new(m, name, receiver, owner)
        end

        def object_singleton_method(context, receiver, name_obj)
          name = sym_name_coercing(context, name_obj)
          sc = receiver.eigenclass
          m = sc&.lookup_method(name)
          unless m && m != ModuleObject::UNDEF_SENTINEL
            raise FrozoneException.make(:NameError, "undefined singleton method '#{name}' for '#{receiver.class_object.full_name}'")
          end
          owner = sc.lookup_method_owner(name) || sc
          BoundMethodObject.new(m, name, receiver, owner)
        end

        def object_public_method(context, receiver, name_obj)
          name = sym_name_coercing(context, name_obj)
          active_refinements = context&.frame&.active_refinements
          m = if active_refinements && !active_refinements.empty?
            receiver.lookup_method_with_refinements(name, active_refinements)
          else
            klass = receiver.eigenclass || receiver.class_object
            klass.lookup_method(name) || receiver.class_object.lookup_method(name)
          end
          unless m
            # public_method checks respond_to_missing? with include_all=false (public only)
            rtm = begin
              receiver.dispatch(context, :respond_to_missing?, [SymbolObject.from(name), FalseObject::FALSE], {}, nil, private_ok: true)
            rescue FrozoneException
              FalseObject::FALSE
            end
            if rtm.truthy?
              owner = receiver.class_object
              bm = BoundMethodObject.new(nil, name, receiver, owner)
              bm.method_missing_dispatch = true
              return bm
            end
            raise FrozoneException.make(:NameError, "undefined method '#{name}' for class '#{receiver.class_object.full_name}'")
          end
          vis = m.respond_to?(:visibility) ? m.visibility : :public
          unless vis == :public
            raise FrozoneException.make(:NameError, "method '#{name}' for class '#{receiver.class_object.full_name}' is #{vis}")
          end
          if receiver.eigenclass&.lookup_method(name)
            owner = receiver.eigenclass.lookup_method_owner(name) || receiver.eigenclass
          else
            owner = receiver.class_object.lookup_method_owner(name) || receiver.class_object
          end
          BoundMethodObject.new(m, name, receiver, owner)
        end

        def bound_method_call(context, receiver, args, kwargs)
          return NilObject::NIL unless receiver.is_a?(BoundMethodObject)
          blk = context.frame.block
          blk = nil if blk.is_a?(NilObject)
          kw = kwargs.is_a?(HashObject) ? kwargs.raw.transform_keys { |k| k.is_a?(SymbolObject) ? k.raw : k.raw.to_sym } : {}
          if receiver.method_missing_dispatch
            receiver.bound_receiver.dispatch(context, :method_missing, [SymbolObject.from(receiver.bound_name)] + args.raw, kw, blk, private_ok: true)
          elsif receiver.raw_method
            # Directly invoke the captured method, bypassing normal lookup (correct for UnboundMethod.bind.call)
            receiver.raw_method.invoke(context, receiver.bound_receiver, args.raw, kw, blk)
          else
            receiver.bound_receiver.dispatch(context, receiver.bound_name, args.raw, kw, blk)
          end
        end

        def bound_method_arity(_, receiver)
          return IntegerObject.new(0) unless receiver.is_a?(BoundMethodObject)
          m = receiver.raw_method
          return IntegerObject.new(-1) unless m  # method_missing synthetic method
          return IntegerObject.new(0) unless m.is_a?(Method)
          req = m.required_params.length
          opt = m.optional_params.length
          rest = m.rest_param && m.rest_param != :__no_rest__
          post = m.post_params.length
          req_kw = m.required_kw_params.length
          opt_kw = m.optional_kw_params.length
          kw_rest = m.kw_rest_param
          req_kw_count = req_kw > 0 ? 1 : 0
          kw_optional = req_kw == 0 && (opt_kw > 0 || (kw_rest && kw_rest != :__no_kwargs__))
          has_opt = rest || post > 0 || opt > 0 || kw_optional
          if has_opt
            IntegerObject.new(-(req + post + req_kw_count + 1))
          else
            IntegerObject.new(req + post + req_kw_count)
          end
        end

        ANON_REST    = :__anon_rest__
        ANON_KWARGS  = :__anon_kwargs__
        ANON_BLOCK   = :__anon_block__
        ANON_REQ     = :__anon_req__

        # Returns nil to indicate the parameter is anonymous (no name in output)
        # ANON_REST maps to :* for both methods and procs (anonymous splat shows as *)
        # __native_xxx__ params: strip name (simulate C-level method signature, no param name shown)
        def normalize_param_name(sym, for_proc: false)
          case sym
          when ANON_REQ                           then nil
          when ANON_REST                          then :*
          when :__forward_args__                  then :*
          when ANON_KWARGS, :__forward_kwargs__   then :**
          when ANON_BLOCK, :__forward_block__     then :&
          when /\A__(?:repeated|discard)_\w+__\z/  then :_
          when /\A__native_\w+__\z/              then nil
          when Hash                               then nil  # multi-target destructuring: no name
          else sym
          end
        end

        def param_entry(type, name, for_proc: false)
          n = normalize_param_name(name, for_proc: for_proc)
          n ? ArrayObject.new([SymbolObject.from(type), SymbolObject.from(n)]) : ArrayObject.new([SymbolObject.from(type)])
        end

        def extract_method_params(m)
          # Resolve DefinedMethod to its underlying block_obj
          m = m.block_obj if m.is_a?(DefinedMethod)
          return [] unless m.is_a?(BlockObject) || m.is_a?(Method)
          params = []
          m.required_params.each { |p| params << param_entry(:req, p) }
          m.optional_params.each { |p, _| params << param_entry(:opt, p) }
          if m.rest_param && m.rest_param != :__no_rest__
            params << param_entry(:rest, m.rest_param)
          end
          m.post_params.each { |p| params << param_entry(:req, p) }
          m.required_kw_params.each { |p| params << ArrayObject.new([SymbolObject.from(:keyreq), SymbolObject.from(p)]) }
          m.optional_kw_params.each { |p, _| params << ArrayObject.new([SymbolObject.from(:key), SymbolObject.from(p)]) }
          if m.kw_rest_param == :__no_kwargs__
            params << ArrayObject.new([SymbolObject.from(:nokey)])
          elsif m.kw_rest_param
            params << param_entry(:keyrest, m.kw_rest_param)
          end
          if m.block_param
            params << param_entry(:block, m.block_param)
          end
          params
        end

        def bound_method_parameters(_, receiver)
          return ArrayObject.new([]) unless receiver.is_a?(BoundMethodObject)
          m = receiver.raw_method
          return ArrayObject.new([ArrayObject.new([SymbolObject.from(:rest)])]) if m.nil?
          ArrayObject.new(extract_method_params(m))
        end

        def bound_method_name(_, receiver)
          return NilObject::NIL unless receiver.is_a?(BoundMethodObject)
          SymbolObject.from(receiver.bound_name)
        end

        def bound_method_original_name(_, receiver)
          return NilObject::NIL unless receiver.is_a?(BoundMethodObject)
          m = receiver.raw_method
          orig = m.is_a?(Method) ? m.name : receiver.bound_name
          SymbolObject.from(orig)
        end

        def bound_method_owner(_, receiver)
          return NilObject::NIL unless receiver.is_a?(BoundMethodObject)
          receiver.bound_owner
        end

        def bound_method_receiver(_, receiver)
          return NilObject::NIL unless receiver.is_a?(BoundMethodObject)
          receiver.bound_receiver
        end

        def bound_method_unbind(_, receiver)
          return NilObject::NIL unless receiver.is_a?(BoundMethodObject)
          UnboundMethodObject.new(receiver.raw_method, receiver.bound_name, receiver.bound_owner)
        end

        FROZONE_CORE_LIB = File.expand_path('../../core', __dir__).freeze

        def bound_method_source_location(_, receiver)
          return NilObject::NIL unless receiver.is_a?(BoundMethodObject)
          m = receiver.raw_method
          # Resolve VisibilityOverride to the underlying method
          m = m.original_owner.lookup_method(m.method_name) if m.is_a?(ModuleObject::VisibilityOverride)
          m = m.block_obj if m.is_a?(DefinedMethod)
          if m.is_a?(Method) && m.source_location
            file, line = m.source_location.split(":")
            if file.start_with?(FROZONE_CORE_LIB)
              rel = file[FROZONE_CORE_LIB.length + 1..]
              ArrayObject.new([StringObject.new("<internal:#{rel}>"), IntegerObject.new(line.to_i)])
            else
              ArrayObject.new([StringObject.new(file), IntegerObject.new(line.to_i)])
            end
          elsif m.is_a?(BlockObject) && m.source_location
            file, line = m.source_location
            ArrayObject.new([StringObject.new(file), IntegerObject.new(line)])
          else
            NilObject::NIL
          end
        end

        def bound_method_dup(_, receiver, freeze_opt = NilObject::NIL)
          return NilObject::NIL unless receiver.is_a?(BoundMethodObject)
          copy = BoundMethodObject.new(receiver.raw_method, receiver.bound_name, receiver.bound_receiver, receiver.bound_owner)
          frozen = freeze_opt.is_a?(NilObject) ? false : freeze_opt.truthy?
          copy.copy_fields_from(receiver, eigenclass: nil, frozen: frozen)
          copy
        end

        def bound_method_hash(_, receiver)
          return IntegerObject.new(0) unless receiver.is_a?(BoundMethodObject)
          m = receiver.raw_method
          body_id = if m.is_a?(Method)
            m.body.object_id
          elsif m.is_a?(DefinedMethod)
            m.block_obj.object_id
          else
            m.object_id
          end
          h = receiver.bound_receiver.object_id ^ body_id
          IntegerObject.new(h)
        end

        def bound_method_super(_, receiver)
          return NilObject::NIL unless receiver.is_a?(BoundMethodObject)
          owner = receiver.bound_owner
          return NilObject::NIL unless owner
          recv = receiver.bound_receiver
          # Determine the lookup class: eigenclass (for extended objects) or class_object
          lookup_klass = recv.is_a?(ObjectObject) ? (recv.eigenclass || recv.class_object) : nil
          lookup_klass ||= owner.is_a?(ClassObject) ? owner : nil
          return NilObject::NIL unless lookup_klass&.respond_to?(:lookup_method_after)
          # For aliased methods, the raw Method preserves its original name (alias_as keeps @name).
          # Use that original name for the ancestor lookup so we find the right super method.
          orig_raw = receiver.raw_method
          # VisibilityOverride: the actual method lives in original_owner under method_name.
          # Use those for lookup so super skips the module where the override was created.
          if orig_raw.is_a?(ModuleObject::VisibilityOverride)
            lookup_name = orig_raw.method_name
            origin = orig_raw.original_owner
          else
            lookup_name = orig_raw.is_a?(Method) ? orig_raw.name : receiver.bound_name
            raw = orig_raw.is_a?(DefinedMethod) ? orig_raw.block_obj : orig_raw
            # For visibility-changed methods, the raw_method has original_owner pointing to
            # the actual defining class. Use that as the origin for super lookup so we skip
            # over the visibility wrapper stored in owner's class.
            origin = (raw.is_a?(Method) && raw.original_owner) || owner
          end
          m = lookup_klass.lookup_method_after(lookup_name, origin)
          return NilObject::NIL unless m && m != ClassObject::UNDEF_FOUND
          super_owner = lookup_klass.lookup_method_owner_after(lookup_name, origin) || lookup_klass
          BoundMethodObject.new(m, lookup_name, recv, super_owner)
        end

        def bound_method_to_proc(_, receiver)
          return NilObject::NIL unless receiver.is_a?(BoundMethodObject)
          ProcObject.new(receiver, lambda: true)
        end

        def bound_method_eql(_, m1, m2)
          return FalseObject::FALSE unless m1.is_a?(BoundMethodObject) && m2.is_a?(BoundMethodObject)
          return FalseObject::FALSE unless m1.bound_receiver.equal?(m2.bound_receiver)
          m1m = m1.raw_method; m2m = m2.raw_method
          # Methods are equal if they share the same implementation body/block
          same = if m1m.nil? && m2m.nil?
            # Both are method_missing synthetic methods: compare by name
            m1.bound_name == m2.bound_name
          elsif m1m.is_a?(Method) && m2m.is_a?(Method)
            m1m.equal?(m2m) || m1m.body.equal?(m2m.body)
          elsif m1m.is_a?(DefinedMethod) && m2m.is_a?(DefinedMethod)
            m1m.equal?(m2m) || m1m.block_obj.equal?(m2m.block_obj)
          else
            m1m.equal?(m2m)
          end
          same ? TrueObject::TRUE : FalseObject::FALSE
        end

        def unbound_method_eq(_, a, b)
          return FalseObject::FALSE unless a.is_a?(UnboundMethodObject) && b.is_a?(UnboundMethodObject)
          # Two unbound methods are equal if they have the same owner and same underlying method body.
          # Aliases have different names but the same raw_method — they should compare equal.
          same = a.unbound_owner.equal?(b.unbound_owner) && a.raw_method.equal?(b.raw_method)
          bool_object_for(same)
        end

        def unbound_method_parameters(_, receiver)
          return ArrayObject.new([]) unless receiver.is_a?(UnboundMethodObject)
          ArrayObject.new(extract_method_params(receiver.raw_method))
        end

        def unbound_method_name(_, receiver)
          return NilObject::NIL unless receiver.is_a?(UnboundMethodObject)
          SymbolObject.from(receiver.unbound_name)
        end

        def unbound_method_original_name(_, receiver)
          return NilObject::NIL unless receiver.is_a?(UnboundMethodObject)
          m = receiver.raw_method
          orig = m.is_a?(Method) ? m.name : receiver.unbound_name
          SymbolObject.from(orig)
        end

        def unbound_method_arity(_, receiver)
          return IntegerObject.new(0) unless receiver.is_a?(UnboundMethodObject)
          m = receiver.raw_method
          return IntegerObject.new(-1) if m.nil?  # method_missing synthetic method
          return IntegerObject.new(0) unless m.is_a?(Method)
          req = m.required_params.length
          opt = m.optional_params.length
          rest = m.rest_param && m.rest_param != :__no_rest__
          post = m.post_params.length
          req_kw = m.required_kw_params.length
          opt_kw = m.optional_kw_params.length
          kw_rest = m.kw_rest_param
          req_kw_count = req_kw > 0 ? 1 : 0
          kw_optional = req_kw == 0 && (opt_kw > 0 || (kw_rest && kw_rest != :__no_kwargs__))
          has_opt = rest || post > 0 || opt > 0 || kw_optional
          if has_opt
            IntegerObject.new(-(req + post + req_kw_count + 1))
          else
            IntegerObject.new(req + post + req_kw_count)
          end
        end

        def unbound_method_source_location(_, receiver)
          return NilObject::NIL unless receiver.is_a?(UnboundMethodObject)
          m = receiver.raw_method
          # Resolve VisibilityOverride to underlying method
          m = m.original_owner.lookup_method(m.method_name) if m.is_a?(ModuleObject::VisibilityOverride)
          m = m.block_obj if m.is_a?(DefinedMethod)
          if m.is_a?(Method) && m.source_location
            file, line = m.source_location.split(":")
            if file.start_with?(FROZONE_CORE_LIB)
              rel = file[FROZONE_CORE_LIB.length + 1..]
              ArrayObject.new([StringObject.new("<internal:#{rel}>"), IntegerObject.new(line.to_i)])
            else
              ArrayObject.new([StringObject.new(file), IntegerObject.new(line.to_i)])
            end
          elsif m.is_a?(BlockObject) && m.source_location
            file, line = m.source_location
            ArrayObject.new([StringObject.new(file), IntegerObject.new(line)])
          else
            NilObject::NIL
          end
        end

        def unbound_method_super(_, receiver)
          return NilObject::NIL unless receiver.is_a?(UnboundMethodObject)
          owner = receiver.unbound_owner
          return NilObject::NIL unless owner&.respond_to?(:lookup_method_after)
          orig_raw = receiver.raw_method
          if orig_raw.is_a?(ModuleObject::VisibilityOverride)
            lookup_name = orig_raw.method_name
            origin = orig_raw.original_owner
          else
            lookup_name = orig_raw.is_a?(Method) ? orig_raw.name : receiver.unbound_name
            raw = orig_raw.is_a?(DefinedMethod) ? orig_raw.block_obj : orig_raw
            origin = (raw.is_a?(Method) && raw.original_owner) || owner
          end
          m = owner.lookup_method_after(lookup_name, origin)
          return NilObject::NIL unless m && m != ClassObject::UNDEF_FOUND
          super_owner = owner.lookup_method_owner_after(lookup_name, origin) || owner
          UnboundMethodObject.new(m, lookup_name, super_owner)
        end

        def unbound_method_dup(_, receiver)
          return NilObject::NIL unless receiver.is_a?(UnboundMethodObject)
          copy = UnboundMethodObject.new(receiver.raw_method, receiver.unbound_name, receiver.unbound_owner)
          receiver.instance_variables_hash.each do |ivar, val|
            copy.set_ivar(ivar, val)
          end
          copy
        end

        def unbound_method_hash(_, receiver)
          return IntegerObject.new(0) unless receiver.is_a?(UnboundMethodObject)
          m = receiver.raw_method
          body_id = if m.is_a?(Method)
            m.body.object_id
          elsif m.is_a?(DefinedMethod)
            m.block_obj.object_id
          else
            m.object_id
          end
          IntegerObject.new(receiver.unbound_owner.object_id ^ body_id)
        end

        def unbound_method_bind(_, receiver, new_receiver)
          return NilObject::NIL unless receiver.is_a?(UnboundMethodObject)
          owner = receiver.unbound_owner
          if owner.is_a?(ClassObject) && owner.is_singleton_class
            # Singleton class method: check based on what the singleton belongs to
            orig = owner.singleton_of
            if orig.is_a?(ClassObject)
              # Class singleton method: bindable to the same class or subclasses
              unless new_receiver.is_a?(ClassObject) && subclass_of_builtin?(new_receiver, orig)
                raise FrozoneException.make(:TypeError, "singleton method called for a different object")
              end
            else
              # Instance singleton method: only bindable to the exact original object
              unless new_receiver.equal?(orig)
                raise FrozoneException.make(:TypeError, "singleton method called for a different object")
              end
            end
          elsif owner.is_a?(ClassObject)
            # Class method: new_receiver must be kind_of? the owner class
            unless new_receiver.is_a?(ObjectObject) && subclass_of_builtin?(new_receiver.class_object, owner)
              raise FrozoneException.make(:TypeError, "bind argument must be an instance of #{owner.name}")
            end
          end
          # Module methods: any receiver allowed
          BoundMethodObject.new(receiver.raw_method, receiver.unbound_name, new_receiver, receiver.unbound_owner)
        end

        def unbound_method_owner(_, receiver)
          return NilObject::NIL unless receiver.is_a?(UnboundMethodObject)
          receiver.unbound_owner
        end

        # Check if a method (UnboundMethodObject) is "defined in Ruby code" (not an intrinsic).
        # A method with an IntrinsicCall body is considered NOT defined in Ruby code.
        # Returns true if the method body consists entirely of IntrinsicCall node(s).
        # A Sequence with one IntrinsicCall, or a bare IntrinsicCall, both count as intrinsic.
        def intrinsic_only_body?(body)
          case body
          when Ast::IntrinsicCall
            true
          when Ast::Sequence
            body.nodes.size == 1 && body.nodes.first.is_a?(Ast::IntrinsicCall)
          else
            false
          end
        end

        # Check if a method (UnboundMethodObject) is "defined in Ruby code" (not an intrinsic).
        # A method whose body is a bare IntrinsicCall (or a Sequence wrapping one) is NOT Ruby code.
        def method_ruby_defined_q(_, receiver)
          return FalseObject::FALSE unless receiver.is_a?(UnboundMethodObject)
          m = receiver.raw_method
          return FalseObject::FALSE unless m.is_a?(Method)
          body = m.body
          return FalseObject::FALSE if intrinsic_only_body?(body)
          TrueObject::TRUE
        end

        # Copy an UnboundMethod into a refinement module as an owned method.
        # Sets refining_module so the imported method can see other refinements from the same module.
        # Updates scopes so that super() resolves through the refinement module's refined class.
        def refinement_import_method(_, refinement, name_obj, unbound_method_obj)
          return NilObject::NIL unless refinement.is_a?(ModuleObject)
          return NilObject::NIL unless unbound_method_obj.is_a?(UnboundMethodObject)
          name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.to_s.to_sym
          raw_m = unbound_method_obj.raw_method
          # Use refinement as the last scope so super resolves through the refinement's class hierarchy.
          new_scopes = (raw_m.scopes || []).dup
          if new_scopes.empty?
            new_scopes = [refinement]
          else
            new_scopes[-1] = refinement
          end
          imported = Method.new(
            new_scopes, name, raw_m.required_params, raw_m.optional_params, raw_m.rest_param,
            raw_m.post_params, raw_m.required_kw_params, raw_m.optional_kw_params, raw_m.kw_rest_param,
            raw_m.block_param, raw_m.locals, raw_m.body,
            uses_block: raw_m.uses_block, source_location: raw_m.source_location
          )
          imported.visibility = raw_m.visibility
          imported.original_owner = refinement
          # Link to the containing refinement module so this method sees other refinements
          refining_mod = refinement.get_ivar(:@__refining_module__)
          imported.refining_module = refining_mod if refining_mod.is_a?(ModuleObject)
          refinement.set_method(name, imported)
          NilObject::NIL
        end

        def module_private_method_defined(context, receiver, name_obj, inherit_obj = TrueObject::TRUE)
          name = sym_name_coercing(context, name_obj)
          inherit = inherit_obj.truthy?
          m = inherit ? receiver.lookup_method(name) : receiver.get_method(name)
          m && m != ModuleObject::UNDEF_SENTINEL && m.visibility == :private ? TrueObject::TRUE : FalseObject::FALSE
        end

        def module_public_method_defined(context, receiver, name_obj, inherit_obj = TrueObject::TRUE)
          name = sym_name_coercing(context, name_obj)
          inherit = inherit_obj.truthy?
          m = inherit ? receiver.lookup_method(name) : receiver.get_method(name)
          m && m != ModuleObject::UNDEF_SENTINEL && m.visibility == :public ? TrueObject::TRUE : FalseObject::FALSE
        end

        def module_protected_method_defined(context, receiver, name_obj, inherit_obj = TrueObject::TRUE)
          name = sym_name_coercing(context, name_obj)
          inherit = inherit_obj.truthy?
          m = inherit ? receiver.lookup_method(name) : receiver.get_method(name)
          m && m != ModuleObject::UNDEF_SENTINEL && m.visibility == :protected ? TrueObject::TRUE : FalseObject::FALSE
        end

        def trigger_method_added(context, receiver, name)
          return unless context  # Guard against bootstrap-time calls without context
          if receiver.is_a?(ClassObject) && receiver.is_singleton_class && receiver.singleton_of
            # Adding to a singleton class → call singleton_method_added on original object
            orig = receiver.singleton_of
            orig.dispatch(context, :singleton_method_added, [SymbolObject.from(name)], {}, nil, private_ok: true)
          else
            # Regular class/module → call method_added on the class/module itself
            receiver.dispatch(context, :method_added, [SymbolObject.from(name)], {}, nil, private_ok: true)
          end
        rescue FrozoneException
          raise  # propagate Frozone exceptions (e.g. NoMethodError when hook is undefined)
        rescue StandardError
          # Suppress MRI-level errors (e.g. during boot when Frozone VM not fully set up)
        end

        def module_display_name(context, receiver)
          if receiver.is_a?(ClassObject) && receiver.is_singleton_class
            attached = receiver.singleton_of
            if attached.is_a?(ModuleObject)
              attached_name = attached.full_name
              attached_name ? attached_name.to_s : begin
                receiver.dispatch(context, :to_s, [], {}).raw rescue "#<Class>"
              end
            else
              begin
                s = receiver.dispatch(context, :to_s, [], {})
                s.is_a?(StringObject) ? s.raw : s.to_s
              rescue FrozoneException, StandardError
                "#<Class>"
              end
            end
          else
            (receiver.is_a?(ModuleObject) ? receiver.full_name : nil)&.to_s || receiver.class.name
          end
        end

        def trigger_method_removed(context, receiver, name)
          return unless context
          if receiver.is_a?(ClassObject) && receiver.is_singleton_class && receiver.singleton_of
            orig = receiver.singleton_of
            orig.dispatch(context, :singleton_method_removed, [SymbolObject.from(name)], {}, nil, private_ok: true)
          else
            receiver.dispatch(context, :method_removed, [SymbolObject.from(name)], {}, nil, private_ok: true)
          end
        rescue FrozoneException
          raise
        rescue StandardError
        end

        def trigger_method_undefined(context, receiver, name)
          return unless context
          if receiver.is_a?(ClassObject) && receiver.is_singleton_class && receiver.singleton_of
            orig = receiver.singleton_of
            orig.dispatch(context, :singleton_method_undefined, [SymbolObject.from(name)], {}, nil, private_ok: true)
          else
            receiver.dispatch(context, :method_undefined, [SymbolObject.from(name)], {}, nil, private_ok: true)
          end
        rescue FrozoneException
          raise
        rescue StandardError
        end

        def coerce_attr_name(context, name_obj)
          if name_obj.is_a?(SymbolObject)
            name_obj.raw
          elsif name_obj.is_a?(StringObject)
            name_obj.raw.to_sym
          else
            type_name = name_obj.is_a?(ObjectObject) ? name_obj.class_object&.name : name_obj.class.name
            has_to_str = begin
              name_obj.dispatch(context, :respond_to?, [SymbolObject.from(:to_str)], {}).truthy?
            rescue FrozoneException
              false
            end
            raise FrozoneException.make(:TypeError, "#{type_name} is not a symbol nor a string") unless has_to_str
            result = name_obj.dispatch(context, :to_str, [], {})
            raise FrozoneException.make(:TypeError, "#{type_name} is not a symbol nor a string") unless result.is_a?(StringObject)
            result.raw.to_sym
          end
        end

        def module_attr_reader(context, receiver, names)
          result = names.raw.map do |name_obj|
            name = coerce_attr_name(context, name_obj)
            ivar = :"@#{name}"
            body = Ast::InstanceVariableRead.new(ivar)
            m = Method.new([receiver], name, [], [], nil, [], [], [], nil, nil, [], body)
            m.visibility = receiver.current_visibility
            receiver.set_method(name, m)
            trigger_method_added(context, receiver, name)
            SymbolObject.from(name)
          end
          ArrayObject.new(result)
        end

        def module_attr_writer(context, receiver, names)
          result = names.raw.map do |name_obj|
            name = coerce_attr_name(context, name_obj)
            setter = :"#{name}="
            ivar = :"@#{name}"
            body = Ast::InstanceVariableWrite.new(ivar, Ast::LocalVariableRead.new(ANON_REQ, 0))
            m = Method.new([receiver], setter, [ANON_REQ], [], nil, [], [], [], nil, nil, [ANON_REQ], body)
            m.visibility = receiver.current_visibility
            receiver.set_method(setter, m)
            trigger_method_added(context, receiver, setter)
            SymbolObject.from(setter)
          end
          ArrayObject.new(result)
        end

        def module_attr_accessor(context, receiver, names)
          result = names.raw.flat_map do |name_obj|
            name = coerce_attr_name(context, name_obj)
            setter = :"#{name}="
            ivar = :"@#{name}"
            reader_body = Ast::InstanceVariableRead.new(ivar)
            rm = Method.new([receiver], name, [], [], nil, [], [], [], nil, nil, [], reader_body)
            rm.visibility = receiver.current_visibility
            receiver.set_method(name, rm)
            trigger_method_added(context, receiver, name)
            writer_body = Ast::InstanceVariableWrite.new(ivar, Ast::LocalVariableRead.new(ANON_REQ, 0))
            wm = Method.new([receiver], setter, [ANON_REQ], [], nil, [], [], [], nil, nil, [ANON_REQ], writer_body)
            wm.visibility = receiver.current_visibility
            receiver.set_method(setter, wm)
            trigger_method_added(context, receiver, setter)
            [SymbolObject.from(name), SymbolObject.from(setter)]
          end
          ArrayObject.new(result)
        end

        def module_set_public(context, receiver, names)    = module_set_visibility(context, receiver, names, :public)
        def module_set_private(context, receiver, names)   = module_set_visibility(context, receiver, names, :private)
        def module_set_protected(context, receiver, names) = module_set_visibility(context, receiver, names, :protected)

        def module_set_class_method_visibility(context, receiver, names_obj, vis)
          sc = receiver.singleton_class
          # vis may come from Frozone-land as a SymbolObject — coerce to raw Symbol
          vis_sym = vis.is_a?(SymbolObject) ? vis.raw : vis
          # Handle array as single argument: private_class_method([:foo, :bar]) → flatten
          name_list = if names_obj.is_a?(ArrayObject)
            nl = names_obj.raw
            nl.size == 1 && nl[0].is_a?(ArrayObject) ? nl[0].raw : nl
          else
            [names_obj]
          end
          name_list.each do |name_obj|
            name = sym_name_coercing(context, name_obj)
            m = sc.get_method(name)
            if m.nil? || m == ModuleObject::UNDEF_SENTINEL
              orig_owner = receiver.lookup_instance_method(name)&.tap { |_| nil } && sc.lookup_method_owner(name)
              # Walk singleton class hierarchy for the method
              found = nil
              sc_walk = sc
              while sc_walk
                fm = sc_walk.get_method(name)
                if fm && fm != ModuleObject::UNDEF_SENTINEL
                  found = [fm, sc_walk]
                  break
                end
                sc_walk = sc_walk.is_a?(ClassObject) ? sc_walk.superclass : nil
              end
              if found.nil?
                exc = FrozoneException.make(:NameError, "undefined method '#{name}' for class '#{receiver.name}'")
                exc.vm_object.set_ivar(:@name, SymbolObject.from(name))
                raise exc
              end
              inherited_m, orig_sc = found
              m = inherited_m.dup_with_visibility(vis_sym, original_owner: orig_sc.equal?(sc) ? nil : orig_sc)
              sc.set_method(name, m)
            else
              m.visibility = vis_sym
            end
          end
          receiver
        end

        def module_function(context, receiver, names)
          raise FrozoneException.make(:TypeError, "module_function is not permitted on classes") if receiver.is_a?(ClassObject)
          name_list = names.is_a?(ArrayObject) ? names.raw : [names]
          if name_list.empty?
            receiver.current_visibility = :module_function
            return NilObject::NIL
          end
          result_names = name_list.map do |name_obj|
            name = sym_name_coercing(context, name_obj)
            m = receiver.get_method(name) || receiver.lookup_method(name) ||
                Core::OBJECT_CLASS.lookup_method(name)
            unless m.nil? || m == ModuleObject::UNDEF_SENTINEL
              # Add as private instance method (don't call method_added — just adjusting visibility)
              m.visibility = :private
              receiver.set_method(name, m)
              # Add as public singleton method (bound to singleton class for super resolution)
              sm = m.respond_to?(:bound_copy) ? m.bound_copy(name, receiver.singleton_class) : m.dup
              sm.visibility = :public
              receiver.singleton_class.set_method(name, sm)
              # Only call singleton_method_added (not method_added) for the copy
              trigger_method_added(context, receiver.singleton_class, name)
            end
            SymbolObject.from(name)
          end
          # Return single symbol or array of symbols
          result_names.size == 1 ? result_names[0] : ArrayObject.new(result_names)
        end

        # Top-level 'main' proxy: delegate to Object
        def toplevel_public(context, _, names)    = module_set_visibility(context, Core::OBJECT_CLASS, names, :public)
        def toplevel_private(context, _, names)   = module_set_visibility(context, Core::OBJECT_CLASS, names, :private)
        def toplevel_protected(context, _, names) = module_set_visibility(context, Core::OBJECT_CLASS, names, :protected)

        # main.define_method(name, callable_or_nil, &block) → delegates to Object.define_method
        # args_array collects [name] or [name, callable]; block is the block arg.
        def toplevel_define_method(context, _, args_array, block)
          args = args_array.raw
          name_obj = args[0]
          callable = args.length > 1 ? args[1] : nil
          effective = if callable.is_a?(NilObject)
            block
          else
            callable
          end
          unless effective && !effective.is_a?(NilObject)
            raise FrozoneException.make(:ArgumentError, "tried to create Proc object without a block")
          end
          # top-level define_method always creates a public method on Object
          # (unlike module context where current_visibility applies)
          prev_vis = Core::OBJECT_CLASS.current_visibility
          Core::OBJECT_CLASS.current_visibility = :public
          begin
            module_define_method(context, Core::OBJECT_CLASS, name_obj, effective)
          ensure
            Core::OBJECT_CLASS.current_visibility = prev_vis
          end
        end

        def toplevel_ruby2_keywords(context, _, names)
          module_ruby2_keywords(context, Core::OBJECT_CLASS, names)
        end

        def toplevel_using(context, _receiver, mod_array)
          mod = mod_array.raw.first
          raise FrozoneException.make(:ArgumentError, "wrong number of arguments (given 0, expected 1)") if mod.nil?
          module_using(context, _receiver, mod)
        end

        def toplevel_include(_, _self, mods)
          target = Fiber[:load_wrap_module] || Core::OBJECT_CLASS
          mods.raw.each { |mod| target.add_module(mod) }
          target
        end

        def object_instance_eval(context, receiver, block)
          return NilObject::NIL if block.is_a?(NilObject)
          # Pass receiver as block arg so |obj| parameters receive self (MRI behaviour)
          return block.invoke(context, [receiver], receiver: receiver, instance_eval_receiver: receiver) if block.is_a?(ProcObject)
          return block.invoke(context, [receiver], receiver: receiver, instance_eval_receiver: receiver) if block.is_a?(BlockObject)
          NilObject::NIL
        end

        def object_instance_eval_string(context, receiver, code_obj, file_obj = NilObject::NIL, line_obj = NilObject::NIL)
          # Coerce code to String via to_str
          code = if code_obj.is_a?(StringObject)
            code_obj.raw
          else
            klass = code_obj.respond_to?(:class_object) ? (code_obj.class_object&.name || code_obj.class) : code_obj.class
            begin
              result = code_obj.dispatch(context, :to_str, [], {})
              raise FrozoneException.make(:TypeError, "can't convert #{klass} into String") unless result.is_a?(StringObject)
              result.raw
            rescue FrozoneException => e
              raise unless e.frozone_class_name == :NoMethodError
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{klass} into String")
            end
          end
          # Coerce filename via to_str
          fname = if file_obj.is_a?(StringObject)
            file_obj.raw
          elsif !file_obj.is_a?(NilObject)
            klass = file_obj.respond_to?(:class_object) ? (file_obj.class_object&.name || file_obj.class) : file_obj.class
            begin
              result = file_obj.dispatch(context, :to_str, [], {})
              raise FrozoneException.make(:TypeError, "can't convert #{klass} into String") unless result.is_a?(StringObject)
              result.raw
            rescue FrozoneException => e
              raise unless e.frozone_class_name == :NoMethodError
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{klass} into String")
            end
          end
          # Coerce line number via to_int
          lnum = if line_obj.is_a?(IntegerObject)
            line_obj.raw
          elsif !line_obj.is_a?(NilObject)
            klass = line_obj.respond_to?(:class_object) ? (line_obj.class_object&.name || line_obj.class) : line_obj.class
            begin
              result = line_obj.dispatch(context, :to_int, [], {})
              raise FrozoneException.make(:TypeError, "can't convert #{klass} into Integer") unless result.is_a?(IntegerObject)
              result.raw
            rescue FrozoneException => e
              raise unless e.frozone_class_name == :NoMethodError
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{klass} into Integer")
            end
          else
            1
          end
          # Default filepath: "(eval at caller:line)"
          # The current frame is instance_eval's own method frame; the caller is one level up.
          caller_frame = context.frames[-2] || context.frame
          eval_filepath = fname || (context.call_site ? "(eval at #{context.call_site})" : "(eval)")
          # Get caller's locals so eval code can access/modify them
          caller_local_names = caller_frame.local_names
          parser = Parser.new(code, filepath: eval_filepath, line: lnum, outer_locals: caller_local_names)
          ast = parser.ast
          # Seed the eval frame with the caller's current local variable values so that
          # reads in the eval see the caller's values, and after the eval we write them back.
          eval_locals = parser.top_level_locals
          # Constant lookup order: receiver singleton, receiver class, then caller scopes
          # (receiver class hierarchy searched via step 2 of ModuleObject.lookup_constant)
          receiver_sc = receiver.singleton_class
          receiver_class = receiver.is_a?(ModuleObject) ? receiver : receiver.class_object
          eval_scopes = caller_frame.scopes + [receiver_class, receiver_sc]
          new_frame = Frame.new(receiver, eval_locals, eval_scopes)
          caller_local_names.each do |name|
            next unless eval_locals.include?(name)
            v = caller_frame.get_local(name)
            new_frame.set_local(name, v) if v
          end
          new_frame.parent_frame = caller_frame
          new_frame.method_frame = new_frame
          # `def` inside instance_eval always targets receiver's singleton class
          new_frame.def_scope = receiver.singleton_class
          # Class variable lookup uses caller's lexical scope (not receiver's singleton)
          caller_mf = caller_frame.method_frame
          new_frame.cvar_scope = caller_mf&.cvar_scope || caller_mf&.def_scope
          context.push_frame(new_frame)
          begin
            result = ast.evaluate(context)
            # Write back any caller locals that were modified in the eval frame
            caller_local_names.each do |name|
              next unless eval_locals.include?(name)
              caller_frame.set_local(name, new_frame.get_local(name))
            end
            result
          ensure
            context.pop_frame
          end
        end

        def object_instance_exec(context, receiver, args, block)
          if block.is_a?(NilObject)
            raise FrozoneException.make(:LocalJumpError, "no block given")
          end
          return block.invoke(context, args.raw, receiver: receiver, instance_eval_receiver: receiver) if block.is_a?(ProcObject)
          return block.invoke(context, args.raw, receiver: receiver, instance_eval_receiver: receiver) if block.is_a?(BlockObject)
          NilObject::NIL
        end

        def object_extend_multi(context, receiver, mods_arr)
          raise FrozoneException.make(:ArgumentError, "wrong number of arguments (given 0, expected 1+)") if mods_arr.raw.empty?
          mods_arr.raw.each { |mod| object_extend(context, receiver, mod) }
          receiver
        end

        def object_extend(context, receiver, mod)
          raise FrozoneException.make(:TypeError, "wrong argument type #{frozone_class_name(mod)} (expected Module)") unless mod.is_a?(ModuleObject)
          raise FrozoneException.make(:TypeError, "wrong argument type #{frozone_class_name(mod)} (expected Module)") if mod.is_a?(ClassObject)
          # Refinement modules cannot be used with Object#extend
          if mod.is_a?(ModuleObject) && mod.get_ivar(:@__refinement__)&.truthy?
            raise FrozoneException.make(:TypeError, "Refinement#extend_object has been removed")
          end
          mod.dispatch(context, :extend_object, [receiver], {}, nil, private_ok: true)
          begin
            mod.dispatch(context, :extended, [receiver], {}, nil, private_ok: true)
          rescue FrozoneException
            # ignore if not defined
          end
          receiver
        end

        def module_extend_object(_, self_mod, obj)
          raise FrozoneException.make(:TypeError, "extend_object is not permitted on classes") if self_mod.is_a?(ClassObject)
          raise FrozoneException.make(:FrozenError, "can't modify frozen #{frozone_class_name(obj)}: #{obj.object_id}") if obj.frozen_object?
          obj.singleton_class.add_module(self_mod)
          obj
        end

        def module_deprecate_constant(_, receiver, names_obj)
          names = names_obj.is_a?(ArrayObject) ? names_obj.raw : [names_obj]
          names.each do |name_obj|
            name = sym_name(name_obj)
            val, = receiver.lookup_constant_with_owner(name)
            raise FrozoneException.make(:NameError, "constant #{receiver.full_name}::#{name} not defined") if val.nil?
            receiver.instance_variable_get(:@deprecated_constants) ||
              receiver.instance_variable_set(:@deprecated_constants, {})
            receiver.instance_variable_get(:@deprecated_constants)[name] = true
          end
          receiver
        end

        # Multi-module include: calls append_features + included hook for each module (reversed).
        def module_include_multi(context, receiver, mods_obj)
          raise FrozoneException.make(:ArgumentError, "wrong number of arguments (given 0, expected 1+)") if mods_obj.raw.empty?
          mods_obj.raw.reverse_each do |mod|
            # Must be a Module but not a Class (MRI allows Module subclass instances)
            is_module = mod.is_a?(ModuleObject) || object_is_a(nil, mod, Core::MODULE_CLASS).truthy?
            is_class  = mod.is_a?(ClassObject)  || object_is_a(nil, mod, Core::CLASS_CLASS).truthy?
            if !is_module || is_class
              type = frozone_class_name(mod)
              raise FrozoneException.make(:TypeError, "wrong argument type #{type} (expected Module)")
            end
            # Refinement modules cannot be included
            if mod.is_a?(ModuleObject) && mod.get_ivar(:@__refinement__)&.truthy?
              raise FrozoneException.make(:TypeError, "Cannot include refinement")
            end
            mod.dispatch(context, :append_features, [receiver], {}, nil, private_ok: true)
            begin
              mod.dispatch(context, :included, [receiver], {}, nil, private_ok: true)
            rescue FrozoneException
              # ignore if not defined (shouldn't happen since Module defines it)
            end
          end
          receiver
        end

        # Multi-module prepend: calls prepend_features + prepended hook for each module (reversed).
        def module_prepend_multi(context, receiver, mods_obj)
          raise FrozoneException.make(:ArgumentError, "wrong number of arguments (given 0, expected 1+)") if mods_obj.raw.empty?
          mods_obj.raw.reverse_each do |mod|
            is_module = mod.is_a?(ModuleObject) || object_is_a(nil, mod, Core::MODULE_CLASS).truthy?
            is_class  = mod.is_a?(ClassObject)  || object_is_a(nil, mod, Core::CLASS_CLASS).truthy?
            if !is_module || is_class
              type = frozone_class_name(mod)
              raise FrozoneException.make(:TypeError, "wrong argument type #{type} (expected Module)")
            end
            # Refinement modules cannot be prepended
            if mod.is_a?(ModuleObject) && mod.get_ivar(:@__refinement__)&.truthy?
              raise FrozoneException.make(:TypeError, "Cannot prepend refinement")
            end
            mod.dispatch(context, :prepend_features, [receiver], {}, nil, private_ok: true)
            begin
              mod.dispatch(context, :prepended, [receiver], {}, nil, private_ok: true)
            rescue FrozoneException
              # ignore if not defined
            end
          end
          receiver
        end

        # Default implementation of Module#append_features — adds self to other's ancestor chain.
        def module_append_features(_, self_mod, other)
          raise FrozoneException.make(:TypeError, "append_features is not permitted on classes") if self_mod.is_a?(ClassObject)
          raise FrozoneException.make(:TypeError, "wrong argument type #{frozone_class_name(other)} (expected Module)") unless other.is_a?(ModuleObject)
          raise FrozoneException.make(:FrozenError, "can't modify frozen #{frozone_class_name(other)}: #{other.full_name || other.object_id}") if other.frozen_object?
          # Cyclic include check
          if other.equal?(self_mod) || (self_mod.respond_to?(:ancestors_list) && self_mod.ancestors_list.any? { |a| a.equal?(other) })
            raise FrozoneException.make(:ArgumentError, "cyclic include detected")
          end
          other.add_module(self_mod)
          other
        end

        # Default implementation of Module#prepend_features — adds self to other's prepend chain.
        def module_prepend_features(_, self_mod, other)
          raise FrozoneException.make(:TypeError, "prepend_features is not permitted on classes") if self_mod.is_a?(ClassObject)
          raise FrozoneException.make(:TypeError, "wrong argument type #{frozone_class_name(other)} (expected Module)") unless other.is_a?(ModuleObject)
          # Cyclic prepend check
          if other.equal?(self_mod) || (self_mod.respond_to?(:ancestors_list) && self_mod.ancestors_list.any? { |a| a.equal?(other) })
            raise FrozoneException.make(:ArgumentError, "cyclic prepend detected")
          end
          other.prepend_module(self_mod)
          other
        end

        # Class
        def class_new(context, klass, args, kwargs, block = NilObject::NIL)
          raise FrozoneException.make(:TypeError, "can't create instance of singleton class") if klass.is_singleton_class
          raise FrozoneException.make(:TypeError, "uninitialized class") if klass.is_a?(ClassObject) && klass.uninitialized_class
          raw_args = args.raw
          raw_kwargs = kwargs.raw.transform_keys { |k| k.is_a?(SymbolObject) ? k.raw : k }
          has_block = block && !block.is_a?(NilObject)
          if klass.equal?(Core::CLASS_CLASS)
            sc_arg = raw_args.first
            if sc_arg && !sc_arg.is_a?(NilObject)
              raise FrozoneException.make(:TypeError, "superclass must be a Class (#{sc_arg.class_object&.name || sc_arg.class} given)") unless sc_arg.is_a?(ClassObject)
              raise FrozoneException.make(:TypeError, "can't make subclass of singleton class") if sc_arg.is_singleton_class
              superclass = sc_arg
            else
              superclass = Core::OBJECT_CLASS
            end
            new_class = ClassObject.new(nil, nil, superclass)
            # Call inherited hook before block runs (MRI behavior)
            begin
              superclass.dispatch(context, :inherited, [new_class], {}, nil, private_ok: true)
            rescue FrozoneException => e
              raise unless e.frozone_class_name == :NoMethodError
            end
            if has_block
              prev_vis = new_class.current_visibility
              new_class.current_visibility = :public
              begin
                block.invoke(context, [new_class], receiver: new_class, def_scope: new_class)
              ensure
                new_class.current_visibility = prev_vis
              end
            end
            return new_class
          elsif klass.equal?(Core::MODULE_CLASS) || klass.equal?(Core::REFINEMENT_CLASS)
            new_mod = ModuleObject.new(nil, nil, klass)
            if has_block
              prev_vis = new_mod.current_visibility
              new_mod.current_visibility = :public
              begin
                block.invoke(context, [new_mod], receiver: new_mod, def_scope: new_mod)
              ensure
                new_mod.current_visibility = prev_vis
              end
            end
            return new_mod
          end
          klass.new_instance(context, raw_args, raw_kwargs, block)
        end

        def subclass_of_builtin?(klass, base_class)
          k = klass
          while k.is_a?(ClassObject)
            return true if k.equal?(base_class)
            k = k.superclass
          end
          false
        end

        def class_allocate(context, klass)
          raise FrozoneException.make(:TypeError, "can't create instance of singleton class") if klass.is_singleton_class
          if klass.equal?(Core::MODULE_CLASS)
            raise FrozoneException.make(:TypeError, "can't create instance of virtual class")
          end
          if klass.equal?(Core::CLASS_CLASS)
            # Class.allocate returns an uninitialized Class instance (no superclass set)
            uninit = ClassObject.new(nil, nil, nil)
            uninit.uninitialized_class = true
            return uninit
          end
          klass.allocate_instance
        end

        def class_superclass(_, klass)
          raise FrozoneException.make(:TypeError, "uninitialized class") if klass.is_a?(ClassObject) && klass.uninitialized_class
          sc = klass.is_a?(ClassObject) ? klass.superclass : nil
          sc.nil? ? NilObject::NIL : sc
        end

        def class_subclasses(_, klass)
          return ArrayObject.new([]) unless klass.is_a?(ClassObject)
          ArrayObject.new(klass.direct_subclasses)
        end

        # Returns the safe string representation of a singleton class's target without dispatching inspect/to_s
        def module_singleton_class_safe_target_str(_, receiver)
          target = receiver.singleton_of
          return StringObject.new("") unless target
          if target.is_a?(ModuleObject)
            n = target.full_name
            s = n ? n.to_s : "#<#{target.is_a?(ClassObject) ? 'Class' : 'Module'}:0x#{target.object_id.to_s(16)}>"
            StringObject.new(s)
          else
            klass = target.class_object
            # Match Object#to_s: use class.to_s (full_name for named, #<Class:0x...> for anonymous)
            class_str = klass ? (klass.name ? klass.full_name.to_s : "#<Class:0x#{klass.object_id.to_s(16)}>") : ""
            StringObject.new("#<#{class_str}:0x#{target.object_id.to_s(16)}>")
          end
        end

        def class_attached_object(_, klass)
          unless klass.is_a?(ClassObject) && klass.is_singleton_class && klass.singleton_of
            name = klass.is_a?(ClassObject) ? (klass.name&.to_s || klass.inspect) : klass.inspect
            raise FrozoneException.make(:TypeError, "`#{name}' is not a singleton class")
          end
          klass.singleton_of
        end

        def bool_object_for(bool) = bool ? TrueObject::TRUE : FalseObject::FALSE
      end
    end
  end
end
