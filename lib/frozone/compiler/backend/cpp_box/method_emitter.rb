# Box-first C++ backend — method signatures, params, body framing,
# returns.
#
# Method signatures: `Ruby::BasicObject* method_name(Ruby::BasicObject*
# arg, ...)`. All slots are `Ruby::BasicObject*`; unboxing happens
# later (if at all) via the TI-driven optimisation pass.

module Frozone
  module Compiler
    module Backend
      module CppBox
        class MethodEmitter
          # Emits a virtual signature + body for a user-defined method
          # (becomes a virtual on Ruby::MainObject).
          def self.emit_user_method(emit, name, method)
            params, locals = build_params(method)
            emit.line "virtual BasicObject* #{name}(#{params}) {"
            emit.indented do
              if method.body
                ExprEmitter.emit_body(emit, method.body, locals: locals, last_is_return: true)
              end
              # Trailing nil-return safety net for fall-through paths.
              emit.line "return nil_instance();"
            end
            emit.line "}"
          end

          # Returns [params_string, locals_set]. Params include required
          # positional + rest + block (rest/block as nullable optionals
          # so callers without a splat/block can omit them). Optional
          # positional + kw params are deferred.
          def self.build_params(method)
            parts = []
            locals = Set.new
            (method.required_params || []).each do |p|
              parts << "BasicObject* #{p}"
              locals << p.to_s
            end
            if method.rest_param
              # `*` (anonymous splat) gives a Symbol with no readable name.
              # Synthesise `_rest` for that case.
              name = method.rest_param.to_s
              name = "_rest" if name.empty? || name == "*"
              parts << "BasicObject* #{name} = nullptr"
              locals << name
            end
            if method.block_param
              name = method.block_param.to_s
              name = "_block" if name.empty? || name == "&"
              parts << "BasicObject* #{name} = nullptr"
              locals << name
            end
            [parts.join(", "), locals]
          end
        end
      end
    end
  end
end
