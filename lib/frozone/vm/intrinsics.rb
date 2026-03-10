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

        def object_ivar_get(_, v, name)
          ivar = name.is_a?(SymbolObject) ? :"@#{name.raw.to_s.delete_prefix('@')}" : name.raw.to_sym
          ivar = :"@#{ivar.to_s.delete_prefix('@')}"
          v.get_ivar(ivar)
        end

        def object_ivar_set(_, v, name, value)
          ivar = name.is_a?(SymbolObject) ? name.raw : name.raw.to_sym
          ivar = :"@#{ivar.to_s.delete_prefix('@')}"
          v.set_ivar(ivar, value)
          value
        end

        def object_ivar_defined(_, v, name)
          ivar = name.is_a?(SymbolObject) ? name.raw : name.raw.to_sym
          ivar = :"@#{ivar.to_s.delete_prefix('@')}"
          bool_object_for(v.get_ivar(ivar) != NilObject::NIL)
        end

        def object_ivar_names(_, v)
          names = v.instance_variable_get(:@instance_variables)&.keys || []
          ArrayObject.new(names.map { |k| SymbolObject.from(k) })
        end

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

        def kernel_raise(context, _receiver, msg = NilObject::NIL, message_arg = nil, _backtrace = nil)
          if msg.is_a?(NilObject)
            # bare `raise` re-raises current exception or raises RuntimeError
            raise FrozoneException.make(:RuntimeError, "RuntimeError")
          elsif msg.is_a?(ClassObject) || msg.is_a?(ModuleObject)
            # raise SomeClass, "message"
            msg_str = message_arg ? message_arg.dispatch(context, :to_s, [], {}).raw : msg.name.to_s
            exc_obj = ObjectObject.new(msg)
            exc_obj.set_ivar(:@message, StringObject.new(msg_str))
            raise FrozoneException.new(exc_obj, msg_str)
          elsif msg.is_a?(StringObject)
            raise FrozoneException.make(:RuntimeError, msg.raw)
          else
            # raise exception_object (must respond to message)
            begin
              msg_str = msg.dispatch(context, :message, [], {})
              msg_str = msg_str.is_a?(StringObject) ? msg_str.raw : msg.to_s
            rescue
              msg_str = "exception"
            end
            raise FrozoneException.new(msg, msg_str)
          end
        end

        def kernel_p(_, _receiver, args)
          args.raw.each { |a| $stdout.puts(a.dispatch(Fiber[:context], :inspect, [], {}).raw) }
          args.raw.length == 1 ? args.raw.first : args
        end

        def kernel_loop(context, _receiver, block)
          return NilObject::NIL if block.nil? || block.is_a?(NilObject)
          loop do
            block.invoke(context, [])
          rescue Ast::BreakException => e
            return e.value
          end
          NilObject::NIL
        end

        def kernel_abort(_, _receiver, msg)
          m = msg.is_a?(NilObject) ? nil : msg.dispatch(Fiber[:context], :to_s, [], {}).raw
          $stderr.puts(m) if m
          exit(1)
        end

        def kernel_exit(_, _receiver, code)
          c = code.is_a?(TrueObject) ? 0 : code.is_a?(FalseObject) ? 1 : code.is_a?(IntegerObject) ? code.raw : 0
          exit(c)
        end

        # BasicObject
        def basic_object___id__(_, v) = IntegerObject.new(v.__id__)

        def basic_object__equal_equal_(_, v1, v2) = bool_object_for(v1.equal?(v2))

        def basic_object_method_missing(context, receiver, name, args, kwargs)
          raise "BasicObject#method_missing name must be a Symbol" unless name.is_a?(Symbol)
          class_name = receiver.class_object.name
          raise FrozoneException.make(:NoMethodError, "undefined method '#{name}' for an instance of #{class_name}")
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

        def object_instance_eval(context, receiver, block)
          return NilObject::NIL if block.nil? || block.is_a?(NilObject)
          return block.invoke(context, [], receiver: receiver) if block.is_a?(ProcObject)
          return block.invoke(context, [], receiver: receiver) if block.is_a?(BlockObject)
          NilObject::NIL
        end

        def object_extend(_, receiver, mod)
          raise "extend: mod must be a ModuleObject" unless mod.is_a?(ModuleObject)
          receiver.singleton_class.add_module(mod)
          receiver
        end

        def module_alias_method(_, receiver, new_name_obj, old_name_obj)
          new_name = new_name_obj.is_a?(SymbolObject) ? new_name_obj.raw : new_name_obj.raw.to_sym
          old_name = old_name_obj.is_a?(SymbolObject) ? old_name_obj.raw : old_name_obj.raw.to_sym
          method = receiver.is_a?(ClassObject) ? receiver.lookup_method(old_name) : receiver.get_method(old_name)
          raise FrozoneException.make(:NameError, "undefined method '#{old_name}'") if method.nil?
          receiver.set_method(new_name, method.alias_as(new_name))
          receiver
        end

        def module_define_method(_, receiver, name_obj, block)
          name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
          block_obj = block.is_a?(ProcObject) ? block.block_object : block
          receiver.set_method(name, DefinedMethod.new(name, block_obj))
          SymbolObject.from(name)
        end

        def module_name(_, receiver)
          receiver.name ? StringObject.new(receiver.name.to_s) : NilObject::NIL
        end

        def module_const_defined(_, receiver, name_obj, _inherit = TrueObject::TRUE)
          name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
          !receiver.get_constant(name).nil? ? TrueObject::TRUE : FalseObject::FALSE
        end

        def module_const_get(_, receiver, name_obj)
          name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
          c = receiver.get_constant(name)
          raise "uninitialized constant #{receiver.name}::#{name}" if c.nil?
          c
        end

        def module_eval(context, receiver, block)
          return NilObject::NIL if block.nil? || block.is_a?(NilObject)
          block.invoke(context, [], receiver: receiver)
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

        def module_instance_methods(_, receiver, include_super_obj = TrueObject::TRUE)
          include_super = include_super_obj.truthy?
          seen = {}
          result = []
          collect = lambda do |mod|
            mod.instance_variable_get(:@methods).each do |name, m|
              next if seen[name]
              seen[name] = true
              result << SymbolObject.from(name) if m.visibility == :public || m.visibility == :protected
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

        def module_method_defined(_, receiver, name_obj)
          name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
          m = receiver.get_method(name)
          m && (m.visibility == :public || m.visibility == :protected) ? TrueObject::TRUE : FalseObject::FALSE
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
          full_path = resolve_load_path(path)
          raise FrozoneException.make(:LoadError, "cannot load such file -- #{path}") if full_path.nil?
          loaded = GLOBALS[:"$LOADED_FEATURES"]
          loaded_paths = loaded.raw.map(&:raw)
          return FalseObject::FALSE if loaded_paths.include?(full_path)
          loaded.push(StringObject.new(full_path))
          Fiber[:vm_evaluate].call(full_path)
          TrueObject::TRUE
        end

        def kernel_integer(context, _receiver, val, base)
          return val if val.is_a?(IntegerObject)
          if val.is_a?(StringObject)
            return IntegerObject.new(Integer(val.raw, base.raw))
          end
          # Object with to_int or to_i
          if val.class_object.lookup_method(:to_int)
            return val.dispatch(context, :to_int, [], {})
          end
          val.dispatch(context, :to_i, [], {})
        end

        def kernel_float(_, _receiver, val)
          FloatObject.new(val.is_a?(FloatObject) ? val.raw : Float(val.raw))
        end

        def kernel_array(_, _receiver, val)
          return val if val.is_a?(ArrayObject)
          return NilObject::NIL.equal?(val) ? ArrayObject.new([]) : ArrayObject.new([val])
        end

        def kernel_dir(_, _receiver)
          stack = Fiber[:file_stack]
          return NilObject::NIL if stack.nil? || stack.empty?
          StringObject.new(File.dirname(stack.last))
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

        # File / Dir
        def file_join(_, parts)
          strs = parts.raw.flat_map { |p| p.is_a?(ArrayObject) ? p.raw.map(&:raw) : p.raw }
          StringObject.new(File.join(*strs))
        end
        def file_dirname(_, path) = StringObject.new(File.dirname(path.raw))
        def file_basename(_, path, suffix = nil)
          result = suffix.nil? || suffix.is_a?(NilObject) ? File.basename(path.raw) : File.basename(path.raw, suffix.raw)
          StringObject.new(result)
        end
        def file_expand_path(_, path, base = nil)
          result = base.nil? || base.is_a?(NilObject) ? File.expand_path(path.raw) : File.expand_path(path.raw, base.raw)
          StringObject.new(result)
        end
        def file_exist(_, path) = bool_object_for(File.exist?(path.raw))
        def file_directory(_, path) = bool_object_for(File.directory?(path.raw))
        def file_file(_, path) = bool_object_for(File.file?(path.raw))
        def file_readable(_, path) = bool_object_for(File.readable?(path.raw))
        def file_executable(_, path) = bool_object_for(File.executable?(path.raw))
        def file_writable(_, path) = bool_object_for(File.writable?(path.raw))
        def file_size(_, path)
          s = File.size?(path.raw)
          s ? IntegerObject.new(s) : NilObject::NIL
        end
        def file_read(_, path) = StringObject.new(File.read(path.raw))
        def file_split(_, path)
          parts = File.split(path.raw)
          ArrayObject.new(parts.map { |p| StringObject.new(p) })
        end
        def dir_pwd(_) = StringObject.new(Dir.pwd)
        def dir_home(_) = StringObject.new(Dir.home)
        def dir_glob(_, pattern)
          ArrayObject.new(Dir.glob(pattern.raw).map { |p| StringObject.new(p) })
        end
        def process_pid(_) = IntegerObject.new(Process.pid)
        def process_euid(_) = IntegerObject.new(Process.euid)

        # Time
        def time_now(_) = TimeObject.new(Time.now)
        def time_minus(_, t, other)
          other.is_a?(TimeObject) ? FloatObject.new(t.raw - other.raw) : TimeObject.new(t.raw - other.raw)
        end
        def time_plus(_, t, secs) = TimeObject.new(t.raw + secs.raw)
        def time_to_f(_, t) = FloatObject.new(t.raw.to_f)
        def time_to_i(_, t) = IntegerObject.new(t.raw.to_i)
        def time_to_s(_, t) = StringObject.new(t.raw.to_s)

        # Regexp
        def regexp_match(_, receiver, str)
          s = str.is_a?(StringObject) ? str.raw : str.raw.to_s
          m = receiver.raw.match(s)
          m ? IntegerObject.new(m.begin(0)) : NilObject::NIL
        end

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

        def string_start_with(_, v, *args) = bool_object_for(v.raw.start_with?(*args.map(&:raw)))
        def string_end_with(_, v, *args)   = bool_object_for(v.raw.end_with?(*args.map(&:raw)))
        def string_include(_, v, s)        = bool_object_for(v.raw.include?(s.raw))
        def string_empty(_, v)             = bool_object_for(v.raw.empty?)
        def string_strip(_, v)             = StringObject.new(v.raw.strip)
        def string_lstrip(_, v)            = StringObject.new(v.raw.lstrip)
        def string_rstrip(_, v)            = StringObject.new(v.raw.rstrip)
        def string_chomp(_, v, sep = nil)
          sep.nil? || sep.is_a?(NilObject) ? StringObject.new(v.raw.chomp) : StringObject.new(v.raw.chomp(sep.raw))
        end
        def string_chop(_, v)              = StringObject.new(v.raw.chop)
        def string_upcase(_, v)            = StringObject.new(v.raw.upcase)
        def string_downcase(_, v)          = StringObject.new(v.raw.downcase)
        def string_capitalize(_, v)        = StringObject.new(v.raw.capitalize)
        def string_reverse(_, v)           = StringObject.new(v.raw.reverse)
        def string_chars(_, v)             = ArrayObject.new(v.raw.chars.map { |c| StringObject.new(c) })
        def string_bytes(_, v)             = ArrayObject.new(v.raw.bytes.map { |b| IntegerObject.new(b) })
        def string_split(_, v, sep = nil, limit = nil)
          sep = nil if sep.is_a?(NilObject)
          limit = nil if limit.is_a?(NilObject)
          parts = if sep.nil?
            v.raw.split
          elsif limit.nil?
            v.raw.split(sep.is_a?(StringObject) ? sep.raw : sep.raw)
          else
            v.raw.split(sep.is_a?(StringObject) ? sep.raw : sep.raw, limit.raw)
          end
          ArrayObject.new(parts.map { |p| StringObject.new(p) })
        end
        def string_gsub(_, v, pattern, replacement = nil)
          pat = pattern.is_a?(StringObject) ? pattern.raw : pattern.raw
          if replacement.nil? || replacement.is_a?(NilObject)
            NilObject::NIL
          else
            StringObject.new(v.raw.gsub(pat, replacement.raw))
          end
        end
        def string_sub(_, v, pattern, replacement)
          pat = pattern.is_a?(StringObject) ? pattern.raw : pattern.raw
          StringObject.new(v.raw.sub(pat, replacement.raw))
        end
        def string_tr(_, v, from, to) = StringObject.new(v.raw.tr(from.raw, to.raw))
        def string_squeeze(_, v, *args)
          args.empty? ? StringObject.new(v.raw.squeeze) : StringObject.new(v.raw.squeeze(*args.map(&:raw)))
        end
        def string_count(_, v, *args) = IntegerObject.new(v.raw.count(*args.map(&:raw)))
        def string_delete(_, v, *args) = StringObject.new(v.raw.delete(*args.map(&:raw)))
        def string_slice(_, v, idx, len = nil)
          result = len.nil? ? v.raw[idx.raw] : v.raw[idx.raw, len.raw]
          result.nil? ? NilObject::NIL : StringObject.new(result)
        end
        def string_index(_, v, sub, offset = nil)
          result = offset.nil? ? v.raw.index(sub.raw) : v.raw.index(sub.raw, offset.raw)
          result.nil? ? NilObject::NIL : IntegerObject.new(result)
        end
        def string_rindex(_, v, sub, offset = nil)
          result = offset.nil? ? v.raw.rindex(sub.raw) : v.raw.rindex(sub.raw, offset.raw)
          result.nil? ? NilObject::NIL : IntegerObject.new(result)
        end
        def string_replace(_, v, other)
          return v if other.is_a?(NilObject)
          StringObject.new(other.raw)
        end
        def string_concat(_, v1, v2)      = StringObject.new(v1.raw + v2.raw)
        def string_multiply(_, v, n)      = StringObject.new(v.raw * n.raw)
        def string_format(_, v, args)
          raw_args = args.is_a?(ArrayObject) ? args.raw.map(&:raw) : args.raw
          StringObject.new(v.raw % raw_args)
        end
        def string_encode(_, v, enc = nil) = v
        def string_encoding(_, v)         = StringObject.new(v.raw.encoding.name)
        def string_freeze(_, v)           = v
        def string_frozen(_, v)           = bool_object_for(false)
        def string_dup(_, v)              = StringObject.new(v.raw.dup)
        def string_to_sym(_, v)           = SymbolObject.from(v.raw.to_sym)
        def string_to_f(_, v)             = FloatObject.new(v.raw.to_f)
        def string_to_r(_, v)             = NilObject::NIL  # stub
        def string_match(_, v, pattern)
          pat = pattern.is_a?(StringObject) ? Regexp.new(pattern.raw) : pattern.raw
          m = pat.match(v.raw)
          m ? IntegerObject.new(m.begin(0)) : NilObject::NIL
        end
        def string_scan(_, v, pattern)
          pat = pattern.is_a?(StringObject) ? Regexp.new(pattern.raw) : pattern.raw
          results = v.raw.scan(pat)
          ArrayObject.new(results.map { |r| r.is_a?(Array) ? ArrayObject.new(r.map { |s| StringObject.new(s) }) : StringObject.new(r) })
        end

        # Symbol
        def symbol_to_s(_, v) = StringObject.new(v.raw.to_s)
        def symbol_inspect(_, v) = StringObject.new(v.raw.inspect)

        def symbol_hash(_, v) = IntegerObject.new(v.raw.hash)

        def symbol_eql(_, v1, v2) = bool_object_for(v2.is_a?(SymbolObject) && v1.raw == v2.raw)

        # Array
        def array_index(_, v, i, len = nil)
          len = nil if len.is_a?(NilObject)
          if len.nil?
            if i.is_a?(RangeObject)
              b = i.begin_val.is_a?(IntegerObject) ? i.begin_val.raw : nil
              e = i.end_val.is_a?(IntegerObject) ? i.end_val.raw : nil
              ruby_range = i.exclusive? ? (b...e) : (b..e)
              result = v.raw[ruby_range]
              result.nil? ? NilObject::NIL : ArrayObject.new(result)
            elsif i.is_a?(IntegerObject)
              element = v[i.raw]
              element.nil? ? NilObject::NIL : element
            else
              raise "Array#[] index must be an Integer or Range (got #{i.class})"
            end
          else
            result = v.raw[i.raw, len.raw]
            result.nil? ? NilObject::NIL : ArrayObject.new(result)
          end
        end

        def array_index_write(_, v, i, val)
          if i.is_a?(IntegerObject)
            v.raw[i.raw] = val
          elsif i.is_a?(RangeObject)
            replacement = val.is_a?(ArrayObject) ? val.raw : [val]
            v.raw[i.raw] = replacement
          else
            raise "Array#[]= index must be an Integer or Range"
          end
          val
        end

        def array_slice_write(_, v, start, length, val)
          raise "Array#[]= start must be an Integer" unless start.is_a?(IntegerObject)
          raise "Array#[]= length must be an Integer" unless length.is_a?(IntegerObject)
          replacement = val.is_a?(ArrayObject) ? val.raw : [val]
          v.raw[start.raw, length.raw] = replacement
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

        def array_eq(context, v1, v2)
          return bool_object_for(false) unless v2.is_a?(ArrayObject)
          return bool_object_for(false) unless v1.raw.length == v2.raw.length
          result = v1.raw.zip(v2.raw).all? { |a, b| a.dispatch(context, :==, [b], {}).truthy? }
          bool_object_for(result)
        end

        def array_eql(context, v1, v2)
          return bool_object_for(false) unless v2.is_a?(ArrayObject)
          return bool_object_for(false) unless v1.raw.length == v2.raw.length
          result = v1.raw.zip(v2.raw).all? { |a, b| a.dispatch(context, :eql?, [b], {}).truthy? }
          bool_object_for(result)
        end

        def array_intersection(_, v1, v2)
          r1 = v1.raw; r2 = v2.raw
          ArrayObject.new(r1 & r2)
        end

        def array_union(_, v1, v2)
          ArrayObject.new(v1.raw | v2.raw)
        end

        def array_difference(_, v1, v2)
          ArrayObject.new(v1.raw - v2.raw)
        end

        def array_plus(_, v1, v2)
          ArrayObject.new(v1.raw + v2.raw)
        end

        def array_multiply(_, v, n)
          n.is_a?(IntegerObject) ? ArrayObject.new(v.raw * n.raw) : StringObject.new(v.raw.map { |e| e.dispatch(Fiber[:context], :to_s, [], {}).raw }.join(n.raw))
        end

        def array_flatten(_, v, depth = nil)
          depth = nil if depth.is_a?(NilObject)
          result = depth.nil? ? v.raw.flatten : v.raw.flatten(depth.raw)
          ArrayObject.new(result.map { |e| e.is_a?(ArrayObject) ? e : e })
        end

        def array_compact(_, v)
          ArrayObject.new(v.raw.reject { |e| e.is_a?(NilObject) })
        end

        def array_uniq(_, v)
          seen = {}
          result = []
          v.raw.each { |e| (seen[e.__id__] = result << e) unless seen[e.__id__] }
          ArrayObject.new(result)
        end

        def array_sort(context, v)
          ArrayObject.new(v.raw.sort { |a, b| a.dispatch(context, :<=>, [b], {}).raw })
        end

        def array_sort_by(context, v, block)
          ArrayObject.new(v.raw.sort_by { |e| block.invoke(context, [e]) })
        end

        def array_min(context, v)
          v.raw.empty? ? NilObject::NIL : v.raw.min { |a, b| a.dispatch(context, :<=>, [b], {}).raw }
        end

        def array_max(context, v)
          v.raw.empty? ? NilObject::NIL : v.raw.max { |a, b| a.dispatch(context, :<=>, [b], {}).raw }
        end

        def array_sum(context, v, initial = nil)
          initial = initial.nil? || initial.is_a?(NilObject) ? IntegerObject.new(0) : initial
          v.raw.reduce(initial) { |acc, e| acc.dispatch(context, :+, [e], {}) }
        end

        def array_join(_, v, sep = nil)
          sep = sep.nil? || sep.is_a?(NilObject) ? '' : sep.raw
          StringObject.new(v.raw.map { |e| e.dispatch(Fiber[:context], :to_s, [], {}).raw }.join(sep))
        end

        def array_include(_, v, elem)
          bool_object_for(v.raw.any? { |e| e.equal?(elem) || (e.respond_to?(:raw) && elem.respond_to?(:raw) && e.raw == elem.raw) })
        end

        def array_empty(_, v) = bool_object_for(v.raw.empty?)

        def array_reverse(_, v) = ArrayObject.new(v.raw.reverse)

        def array_pop(_, v)
          val = v.raw.pop
          val.nil? ? NilObject::NIL : val
        end

        def array_shift(_, v)
          val = v.raw.shift
          val.nil? ? NilObject::NIL : val
        end

        def array_unshift(_, v, *elems)
          elems.each { |e| v.raw.unshift(e) }
          v
        end

        def array_concat(_, v1, v2)
          v2.raw.each { |e| v1.raw << e }
          v1
        end

        def array_replace(_, v, other)
          v.raw.replace(other.raw)
          v
        end

        def array_delete(_, v, elem)
          removed = v.raw.reject! { |e| e.equal?(elem) || (e.respond_to?(:raw) && elem.respond_to?(:raw) && e.raw == elem.raw) }
          removed.nil? ? NilObject::NIL : elem
        end

        def array_delete_if(context, v, block)
          v.raw.reject! { |e| block.invoke(context, [e]).truthy? }
          v
        end

        def array_index_of(_, v, elem)
          idx = v.raw.index { |e| e.equal?(elem) || (e.respond_to?(:raw) && elem.respond_to?(:raw) && e.raw == elem.raw) }
          idx.nil? ? NilObject::NIL : IntegerObject.new(idx)
        end

        def array_count(context, v, block = nil)
          return IntegerObject.new(v.raw.size) if block.nil? || block.is_a?(NilObject)
          IntegerObject.new(v.raw.count { |e| block.invoke(context, [e]).truthy? })
        end

        def array_each_with_object(context, v, obj, block)
          v.raw.each { |e| block.invoke(context, [e, obj]) }
          obj
        end

        def array_flat_map(context, v, block)
          ArrayObject.new(v.raw.flat_map { |e| r = block.invoke(context, [e]); r.is_a?(ArrayObject) ? r.raw : [r] })
        end

        def array_zip(_, v, *others)
          result = v.raw.zip(*others.map { |o| o.is_a?(ArrayObject) ? o.raw : o.raw })
          ArrayObject.new(result.map { |r| ArrayObject.new(r.map { |e| e.nil? ? NilObject::NIL : e }) })
        end

        def array_take(_, v, n) = ArrayObject.new(v.raw.take(n.raw))
        def array_drop(_, v, n) = ArrayObject.new(v.raw.drop(n.raw))

        def array_rotate(_, v, n = nil)
          n = n.nil? || n.is_a?(NilObject) ? 1 : n.raw
          ArrayObject.new(v.raw.rotate(n))
        end

        def array_sample(_, v) = v.raw.empty? ? NilObject::NIL : v.raw.sample
        def array_shuffle(_, v) = ArrayObject.new(v.raw.shuffle)
        def array_dup(_, v) = ArrayObject.new(v.raw.dup)
        def array_freeze(_, v) = v
        def array_frozen(_, v) = bool_object_for(false)
        def array_to_a(_, v) = v
        def array_to_h(context, v, block = nil)
          result = HashObject.new
          v.raw.each do |e|
            if block && !block.is_a?(NilObject)
              pair = block.invoke(context, [e])
              result[pair.raw[0]] = pair.raw[1]
            elsif e.is_a?(ArrayObject)
              result[e.raw[0]] = e.raw[1]
            end
          end
          result
        end

        def array_combination(context, v, n, block = nil)
          combos = v.raw.combination(n.raw).map { |c| ArrayObject.new(c) }
          return ArrayObject.new(combos) if block.nil? || block.is_a?(NilObject)
          combos.each { |c| block.invoke(context, [c]) }
          v
        end

        def array_permutation(context, v, n = nil, block = nil)
          n = n.nil? || n.is_a?(NilObject) ? v.raw.length : n.raw
          perms = v.raw.permutation(n).map { |p| ArrayObject.new(p) }
          return ArrayObject.new(perms) if block.nil? || block.is_a?(NilObject)
          perms.each { |p| block.invoke(context, [p]) }
          v
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

        def hash_eq(context, v1, v2)
          return bool_object_for(false) unless v2.is_a?(HashObject)
          return bool_object_for(false) unless v1.raw.length == v2.raw.length
          result = v1.raw.all? do |k1, val1|
            pair2 = v2.raw.find { |k2, _| k1.dispatch(context, :==, [k2], {}).truthy? }
            pair2 && val1.dispatch(context, :==, [pair2[1]], {}).truthy?
          end
          bool_object_for(result)
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

        def hash_new(_, default = nil)
          HashObject.new({})  # TODO: support default value
        end

        def hash_each(context, h, block)
          h.raw.each { |k, v| block.invoke(context, [k, v]) }
          h
        end

        def hash_each_pair(context, h, block)
          h.raw.each { |k, v| block.invoke(context, [k, v]) }
          h
        end

        def hash_each_key(context, h, block)
          h.raw.each { |k, _v| block.invoke(context, [k]) }
          h
        end

        def hash_each_value(context, h, block)
          h.raw.each { |_k, v| block.invoke(context, [v]) }
          h
        end

        def hash_keys(_, h) = ArrayObject.new(h.raw.keys)
        def hash_values(_, h) = ArrayObject.new(h.raw.values)
        def hash_to_a(_, h) = ArrayObject.new(h.raw.map { |k, v| ArrayObject.new([k, v]) })
        def hash_empty(_, h) = bool_object_for(h.raw.empty?)

        def hash_merge(_, h1, h2)
          result = h1.raw.merge(h2.raw)
          new_h = HashObject.new
          result.each { |k, v| new_h[k] = v }
          new_h
        end

        def hash_update(_, h1, h2)
          h2.raw.each { |k, v| h1[k] = v }
          h1
        end

        def hash_delete(_, h, key)
          val = h[key]
          h.delete(key)
          val.nil? ? NilObject::NIL : val
        end

        def hash_fetch(context, h, key, default_val = nil)
          val = h[key]
          return val unless val.nil?
          return default_val unless default_val.nil?
          raise FrozoneException.make(:KeyError, "key not found")
        end

        def hash_select(context, h, block)
          new_h = HashObject.new
          h.raw.each { |k, v| new_h[k] = v if block.invoke(context, [k, v]).truthy? }
          new_h
        end

        def hash_reject(context, h, block)
          new_h = HashObject.new
          h.raw.each { |k, v| new_h[k] = v unless block.invoke(context, [k, v]).truthy? }
          new_h
        end

        def hash_map(context, h, block)
          ArrayObject.new(h.raw.map { |k, v| block.invoke(context, [k, v]) })
        end

        def hash_any(context, h, block)
          bool_object_for(h.raw.any? { |k, v| block.invoke(context, [k, v]).truthy? })
        end

        def hash_all(context, h, block)
          bool_object_for(h.raw.all? { |k, v| block.invoke(context, [k, v]).truthy? })
        end

        def hash_none(context, h, block)
          bool_object_for(h.raw.none? { |k, v| block.invoke(context, [k, v]).truthy? })
        end

        def hash_to_s(_, h)
          pairs = h.raw.map { |k, v| "#{k.dispatch(Fiber[:context], :inspect, [], {}).raw}=>#{v.dispatch(Fiber[:context], :inspect, [], {}).raw}" }
          StringObject.new("{#{pairs.join(', ')}}")
        end

        def hash_value(_, h, v) = bool_object_for(h.raw.any? { |_k, val| val.equal?(v) })

        def hash_freeze(_, h) = h
        def hash_frozen(_, h) = bool_object_for(false)
        def hash_dup(_, h)
          new_h = HashObject.new
          h.raw.each { |k, v| new_h[k] = v }
          new_h
        end

        def hash_count(context, h, block = nil)
          return IntegerObject.new(h.raw.size) if block.nil?
          IntegerObject.new(h.raw.count { |k, v| block.invoke(context, [k, v]).truthy? })
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
