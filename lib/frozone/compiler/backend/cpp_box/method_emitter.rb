# Box-first C++ backend — method signatures, params, body framing,
# returns.
#
# Universal call protocol: every Ruby method takes
#   m_X(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr).
# Bodies unpack required positional params from `args` via
# array_at(args, i). Block is always available as `_block` (or
# user-named &blk). Specialisation slots like `m_X_<arity>(arg)`
# are a future optimisation layer; not generated here.

module Frozone
  module Compiler
    module Backend
      module CppBox
        class MethodEmitter
          # Writes a virtual method on a user class (or MainObject).
          def self.write_user_method(emit, name, method)
            cpp_name = Cpp.method_name(name)
            block_name = block_param_name(method)
            emit.line "virtual BasicObject* #{cpp_name}(Array* args, Hash* kwargs = nullptr, Proc* #{block_name} = nullptr) {"
            emit.indented do
              locals = unpack_params(emit, method)
              if method.body
                ExprEmitter.write_body(emit, method.body, locals: locals, last_is_return: true)
              end
              emit.line "return nil_instance();"
            end
            emit.line "}"
          end

          # Emit unpack-from-args lines for each required positional
          # param. Returns the locals set known to be in scope inside
          # the body (param names + block name).
          def self.unpack_params(emit, method)
            locals = Set.new
            required = method.required_params || []
            required.each_with_index do |p, i|
              emit.line "BasicObject* #{p} = array_at(args, #{i});"
              locals << p.to_s
            end
            if method.rest_param
              # Rest collection: gather args[required.length..end] into
              # a new Array. The whole args Array is passed when there
              # are no required params (common case for `def foo(*xs)`).
              name = method.rest_param.to_s
              name = "_rest" if name.empty? || name == "*"
              if required.empty?
                emit.line "BasicObject* #{name} = args;  // *rest = whole args"
              else
                emit.line "Array* #{name} = new Array();"
                emit.line "for (std::size_t _i = #{required.length}; _i < args->data.size(); _i++) {"
                emit.line "  #{name}->data.push_back(args->data[_i]);"
                emit.line "}"
              end
              locals << name
            end
            locals << block_param_name(method)
            locals
          end

          def self.block_param_name(method)
            return "_block" unless method.block_param
            n = method.block_param.to_s
            (n.empty? || n == "&") ? "_block" : n
          end

          # Legacy direct-positional sig — used by build_ctor in
          # emitter.rb. Constructors don't go through the universal
          # call protocol; they're invoked via `new ClassName(args...)`
          # from ExprEmitter's special `.new` handling.
          def self.build_params(method)
            parts = []
            locals = Set.new
            (method.required_params || []).each do |p|
              parts << "BasicObject* #{p}"
              locals << p.to_s
            end
            [parts.join(", "), locals]
          end
        end
      end
    end
  end
end
