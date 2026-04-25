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
          # Writes a virtual signature + body for a user-defined method
          # (becomes a virtual on Ruby::MainObject).
          def self.write_user_method(emit, name, method)
            params, locals = build_params(method)
            cpp_name = Cpp.method_name(name)
            emit.line "virtual BasicObject* #{cpp_name}(#{params}) {"
            emit.indented do
              if method.body
                ExprEmitter.write_body(emit, method.body, locals: locals, last_is_return: true)
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
          #
          # Methods whose body contains `yield` (without an explicit
          # block_param) get an implicit `Proc* _block = nullptr`
          # trailing param. Cpp.from_yield emits `_block->m_call(...)`.
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
            block_name = nil
            if method.block_param
              block_name = method.block_param.to_s
              block_name = "_block" if block_name.empty? || block_name == "&"
              parts << "Proc* #{block_name} = nullptr"
              locals << block_name
            elsif method.body && contains_yield?(method.body)
              # Implicit _block — no block_param declared but yield used.
              parts << "Proc* _block = nullptr"
              locals << "_block"
            end
            [parts.join(", "), locals]
          end

          def self.contains_yield?(node)
            return false unless node.is_a?(Ast::Node)
            return true if node.is_a?(Ast::Yield)
            node.respond_to?(:children) && node.children.any? { |c| contains_yield?(c) }
          end
        end
      end
    end
  end
end
