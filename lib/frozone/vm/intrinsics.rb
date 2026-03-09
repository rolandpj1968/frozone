module Frozone
  module Vm
    module Intrinsics
      StrictTypes = true

      class << self
        def bool_object_for(bool) = bool ? TrueObject::TRUE : FalseObject::FALSE

        # Object
        def object_class(_, v) = v.class_object

        def object_is_a(_, v, klass)
          c = v.class_object
          until c.nil?
            return TrueObject::TRUE if c.equal?(klass)
            return TrueObject::TRUE if c.prepends.any? { |m| m.equal?(klass) }
            return TrueObject::TRUE if c.modules.any? { |m| m.equal?(klass) }
            c = c.superclass
          end
          FalseObject::FALSE
        end

        def object_instance_of(_, v, klass) = bool_object_for(v.class_object.equal?(klass))

        def object_not(_, v) = bool_object_for(!v.truthy?)

        def object_respond_to(_, v, name)
          raise "respond_to? name must be a SymbolObject" unless name.is_a?(SymbolObject)
          bool_object_for(!v.class_object.lookup_method(name.raw).nil?)
        end

        def object_to_s(_, v)
          StringObject.new("#<#{v.class_object.name}:0x#{v.__id__.to_s(16)}>")
        end

        # Kernel (on Object for now)
        def kernel_puts(_, _receiver, args)
          if args.raw.empty?
            $stdout.puts
          else
            args.raw.each { |a| $stdout.puts(a.dispatch(Fiber[:context], :to_s, [], {}).raw) }
          end
          NilObject::NIL
        end

        def kernel_print(_, _receiver, args)
          args.raw.each { |a| $stdout.print(a.dispatch(Fiber[:context], :to_s, [], {}).raw) }
          NilObject::NIL
        end

        def kernel_raise(_, _receiver, msg)
          message = msg.is_a?(NilObject) ? 'RuntimeError' : msg.dispatch(Fiber[:context], :to_s, [], {}).raw
          raise FrozoneException.new(msg, message)
        end

        def kernel_p(_, _receiver, args)
          args.raw.each { |a| $stdout.puts(a.dispatch(Fiber[:context], :inspect, [], {}).raw) }
          args.raw.length == 1 ? args.raw.first : args
        end

        # BasicObject
        def basic_object___id__(_, v) = IntegerObject.new(v.__id__)

        def basic_object__equal_equal_(_, v1, v2) = bool_object_for(v1.equal?(v2))

        def basic_object_method_missing(context, receiver, name, args, kwargs)
          raise "BasicObject#method_missing name must be a Symbol" unless name.is_a?(Symbol)
          class_name = receiver.class_object.name
          raise "undefined method '#{name}' for an instance of #{class_name}"
        end

        def basic_object___send__(context, receiver, name, args, kwargs)
          raise "BasicObject#__send__ name must be a SymbolObject" unless name.is_a?(SymbolObject)
          raw_kwargs = kwargs.raw.transform_keys { |k| k.is_a?(SymbolObject) ? k.raw : k }
          receiver.dispatch(context, name.raw, args.raw, raw_kwargs, nil, private_ok: true)
        end

        # Module
        def module_include(_, receiver, mod)
          raise "module_include: receiver must be a ModuleObject" unless receiver.is_a?(ModuleObject)
          raise "module_include: mod must be a ModuleObject" unless mod.is_a?(ModuleObject)
          receiver.add_module(mod)
          receiver
        end

        def module_prepend(_, receiver, mod)
          raise "module_prepend: receiver must be a ModuleObject" unless receiver.is_a?(ModuleObject)
          raise "module_prepend: mod must be a ModuleObject" unless mod.is_a?(ModuleObject)
          receiver.prepend_module(mod)
          receiver
        end

        def module_attr_reader(_, receiver, names)
          raise "attr_reader: receiver must be a ModuleObject" unless receiver.is_a?(ModuleObject)
          names.raw.each do |name_obj|
            name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
            ivar = :"@#{name}"
            body = Ast::InstanceVariableRead.new(ivar)
            m = Method.new([receiver], name, [], [], nil, [], [], [], nil, nil, [], body)
            receiver.set_method(name, m)
          end
          NilObject::NIL
        end

        def module_attr_writer(_, receiver, names)
          raise "attr_writer: receiver must be a ModuleObject" unless receiver.is_a?(ModuleObject)
          names.raw.each do |name_obj|
            name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
            setter = :"#{name}="
            ivar = :"@#{name}"
            body = Ast::InstanceVariableWrite.new(ivar, Ast::LocalVariableRead.new(:value, 0))
            m = Method.new([receiver], setter, [:value], [], nil, [], [], [], nil, nil, [], body)
            receiver.set_method(setter, m)
          end
          NilObject::NIL
        end

        def module_attr_accessor(context, receiver, names)
          module_attr_reader(context, receiver, names)
          module_attr_writer(context, receiver, names)
          NilObject::NIL
        end

        def module_set_public(context, receiver, names)    = module_set_visibility(context, receiver, names, :public)
        def module_set_private(context, receiver, names)   = module_set_visibility(context, receiver, names, :private)
        def module_set_protected(context, receiver, names) = module_set_visibility(context, receiver, names, :protected)

        # Top-level 'main' proxy: delegate to Object
        def toplevel_public(context, _, names)    = module_set_visibility(context, Core::OBJECT_CLASS, names, :public)
        def toplevel_private(context, _, names)   = module_set_visibility(context, Core::OBJECT_CLASS, names, :private)
        def toplevel_protected(context, _, names) = module_set_visibility(context, Core::OBJECT_CLASS, names, :protected)

        private

        def module_set_visibility(_, receiver, names, vis)
          raise "module_set_visibility: receiver must be a ModuleObject" unless receiver.is_a?(ModuleObject)
          if names.raw.empty?
            receiver.current_visibility = vis
          else
            names.raw.each do |name_obj|
              name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
              m = receiver.get_method(name)
              raise "undefined method '#{name}' for class '#{receiver.name}'" if m.nil?
              m.visibility = vis
            end
          end
          NilObject::NIL
        end

        public

        # Kernel require/load
        def kernel_require(_, _receiver, path_obj)
          path = path_obj.raw
          loaded = GLOBALS[:"$LOADED_FEATURES"]
          loaded_paths = loaded.raw.map(&:raw)
          return FalseObject::FALSE if loaded_paths.include?(path)
          full_path = resolve_load_path(path)
          return FalseObject::FALSE if full_path.nil?
          loaded.push(StringObject.new(full_path))
          Fiber[:vm_evaluate].call(full_path)
          TrueObject::TRUE
        end

        def kernel_require_relative(_, _receiver, path_obj)
          rel = path_obj.raw
          stack = Fiber[:file_stack]
          raise "require_relative called outside of a file" if stack.nil? || stack.empty?
          full_path = File.expand_path(rel, File.dirname(stack.last))
          full_path += '.rb' unless full_path.end_with?('.rb')
          loaded = GLOBALS[:"$LOADED_FEATURES"]
          loaded_paths = loaded.raw.map(&:raw)
          return FalseObject::FALSE if loaded_paths.include?(full_path)
          loaded.push(StringObject.new(full_path))
          Fiber[:vm_evaluate].call(full_path)
          TrueObject::TRUE
        end

        def kernel_load(_, _receiver, path_obj)
          path = path_obj.raw
          full_path = File.exist?(path) ? path : resolve_load_path(path)
          raise "cannot load such file -- #{path}" if full_path.nil?
          Fiber[:vm_evaluate].call(full_path)
          TrueObject::TRUE
        end

        def kernel_proc(context, _receiver)
          block = context.frame.block
          raise "proc called without a block" if block.nil?
          ProcObject.new(block)
        end

        def kernel_lambda(context, _receiver)
          block = context.frame.block
          raise "lambda called without a block" if block.nil?
          ProcObject.new(block, lambda: true)
        end

        def proc_call(context, proc_obj, args)
          raise "proc_call: receiver must be a ProcObject" unless proc_obj.is_a?(ProcObject)
          proc_obj.call(context, args.raw)
        end

        private

        def resolve_load_path(path)
          path_rb = path.end_with?('.rb') ? path : "#{path}.rb"
          return path_rb if File.exist?(path_rb)
          load_path = GLOBALS[:"$LOAD_PATH"]
          load_path&.raw&.each do |dir_obj|
            full = File.join(dir_obj.raw, path_rb)
            return full if File.exist?(full)
          end
          nil
        end

        public

        # Class
        def class_new(context, klass, args, kwargs) = klass.new_instance(context, args.raw, kwargs.raw)

        # Integer
        def integer_spaceship(_, v1, v2)
          return NilObject::NIL unless v2.is_a?(IntegerObject)
          IntegerObject.new(v1.raw <=> v2.raw)
        end

        def integer_hash(_, v) = IntegerObject.new(v.raw.hash)

        def integer_eql(_, v1, v2) = bool_object_for(v2.is_a?(IntegerObject) && v1.raw == v2.raw)

        def integer_to_s(_, v) = StringObject.new(v.raw.to_s)
        def integer_abs(_, v) = IntegerObject.new(v.raw.abs)

        # Integer generated methods
        def is_int(v) = v.is_a?(IntegerObject)

        def check_integer_bin_args(op) = ("raise 'BUG: Integer #{op} intrinsic called with non-Integer values' unless is_int(v1) and is_int(v2)" if StrictTypes)

        def def_integer_cmp(name, op) = eval "def integer_#{name}(_, v1, v2); #{check_integer_bin_args(op)}; bool_object_for(v1.raw #{op} v2.raw); end"

        def def_integer_bin_op(name, op) = eval "def integer_#{name}(_, v1, v2); #{check_integer_bin_args(op)}; IntegerObject.new(v1.raw #{op} v2.raw); end"

        # String
        def string_plus(_, v1, v2)
          raise "String#+ requires a String argument" unless v2.is_a?(StringObject)
          StringObject.new(v1.raw + v2.raw)
        end

        def string_length(_, v) = IntegerObject.new(v.raw.length)
        def string_to_s(_, v) = v
        def string_to_i(_, v) = IntegerObject.new(v.raw.to_i)
        def string_inspect(_, v) = StringObject.new(v.raw.inspect)

        def string_spaceship(_, v1, v2)
          return NilObject::NIL unless v2.is_a?(StringObject)
          IntegerObject.new(v1.raw <=> v2.raw)
        end

        def string_hash(_, v) = IntegerObject.new(v.raw.hash)

        def string_eql(_, v1, v2) = bool_object_for(v2.is_a?(StringObject) && v1.raw == v2.raw)

        # Symbol
        def symbol_to_s(_, v) = StringObject.new(v.raw.to_s)
        def symbol_inspect(_, v) = StringObject.new(v.raw.inspect)

        def symbol_hash(_, v) = IntegerObject.new(v.raw.hash)

        def symbol_eql(_, v1, v2) = bool_object_for(v2.is_a?(SymbolObject) && v1.raw == v2.raw)

        # Array
        def array_index(_, v, i)
          raise "Array#[] index must be an Integer" unless i.is_a?(IntegerObject)
          element = v[i.raw]
          element.nil? ? NilObject::NIL : element
        end

        def array_index_write(_, v, i, val)
          raise "Array#[]= index must be an Integer" unless i.is_a?(IntegerObject)
          v[i.raw] = val
          val
        end

        def array_push(_, v, val)
          v.push(val)
          v
        end

        def array_length(_, v) = IntegerObject.new(v.length)

        def array_to_s(context, v)
          inner = v.raw.map { |e| e.dispatch(context, :inspect, [], {}).raw }.join(", ")
          StringObject.new("[#{inner}]")
        end

        def array_hash(context, v)
          hash_val = v.raw.reduce(0) { |acc, e| acc * 31 + e.dispatch(context, :hash, [], {}).raw }
          IntegerObject.new(hash_val)
        end

        def array_eql(context, v1, v2)
          return bool_object_for(false) unless v2.is_a?(ArrayObject)
          return bool_object_for(false) unless v1.raw.length == v2.raw.length
          result = v1.raw.zip(v2.raw).all? { |a, b| a.dispatch(context, :eql?, [b], {}).truthy? }
          bool_object_for(result)
        end

        # Range
        def range_each(context, range, block)
          raise "Range#each requires a block" if block.nil? || block.is_a?(NilObject)
          raise "Range#each only supports Integer ranges" unless range.begin_val.is_a?(IntegerObject)
          b = range.begin_val.raw
          e = range.end_val.is_a?(NilObject) ? nil : range.end_val.raw
          i = b
          while e.nil? || (range.exclusive? ? i < e : i <= e)
            block.call(context, [IntegerObject.new(i)])
            i += 1
          end
          range
        end

        def range_to_a(context, range)
          raise "Range#to_a only supports Integer ranges" unless range.begin_val.is_a?(IntegerObject)
          b = range.begin_val.raw
          e = range.end_val.is_a?(NilObject) ? nil : range.end_val.raw
          return ArrayObject.new([]) if e.nil?
          arr = (range.exclusive? ? b...e : b..e).map { |i| IntegerObject.new(i) }
          ArrayObject.new(arr)
        end

        def range_include(context, range, val)
          b = range.begin_val
          e = range.end_val
          return FalseObject::FALSE if b.is_a?(NilObject) && e.is_a?(NilObject)
          above_begin = b.is_a?(NilObject) || b.dispatch(context, :<=, [val], {}).truthy?
          end_op      = range.exclusive? ? :< : :<=
          below_end   = e.is_a?(NilObject) || val.dispatch(context, end_op, [e], {}).truthy?
          bool_object_for(above_begin && below_end)
        end

        def range_size(context, range)
          return NilObject::NIL unless range.begin_val.is_a?(IntegerObject) && range.end_val.is_a?(IntegerObject)
          b = range.begin_val.raw
          e = range.end_val.raw
          size = range.exclusive? ? [e - b, 0].max : [e - b + 1, 0].max
          IntegerObject.new(size)
        end

        def range_begin(_, range) = range.begin_val
        def range_end(_, range)   = range.end_val
        def range_exclude_end(_, range) = bool_object_for(range.exclusive?)

        def range_to_s(context, range)
          b = range.begin_val.dispatch(context, :inspect, [], {}).raw
          e = range.end_val.dispatch(context, :inspect, [], {}).raw
          StringObject.new("#{b}#{range.exclusive? ? '...' : '..'}#{e}")
        end

        # Hash
        def hash_index_write(_, h, key, value)
          h[key] = value
          value
        end

        def hash_size(_, h) = IntegerObject.new(h.size)

        def hash_key(_, h, key) = bool_object_for(h.key?(key))

        def hash_hash(context, v)
          hash_val = v.raw.reduce(0) { |acc, (k, val)| acc ^ (k.dispatch(context, :hash, [], {}).raw ^ val.dispatch(context, :hash, [], {}).raw) }
          IntegerObject.new(hash_val)
        end

        def hash_index(context, h, key)
          value = h[key]
          value.nil? ? NilObject::NIL : value
        end

        def hash_eql(context, v1, v2)
          return bool_object_for(false) unless v2.is_a?(HashObject)
          return bool_object_for(false) unless v1.raw.length == v2.raw.length
          result = v1.raw.all? do |k1, val1|
            pair2 = v2.raw.find { |k2, _| k1.dispatch(context, :eql?, [k2], {}).truthy? }
            pair2 && val1.dispatch(context, :eql?, [pair2[1]], {}).truthy?
          end
          bool_object_for(result)
        end
      end

      # Integer
      def_integer_cmp('_lt_', '<')
      def_integer_cmp('_le_', '<=')
      def_integer_cmp('_ge_', '>=')
      def_integer_cmp('_gt_', '>')
      def_integer_cmp('_eq_', '==') # TODO - should be alias for ===

      def_integer_bin_op('_plus_', '+')
      def_integer_bin_op('_minus_', '-')
      def_integer_bin_op('_mul_', '*')
      def_integer_bin_op('_div_', '/')
      def_integer_bin_op('_mod_', '%')
      def_integer_bin_op('_pow_', '**')
    end
  end
end
