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
          # Captures the body first so an EmissionError mid-body leaves
          # nothing committed — the method is silently skipped (it falls
          # through to BasicObject's universal m_X stub at runtime,
          # which calls method_missing).
          def self.write_user_method(emit, name, method)
            cpp_name = Cpp.method_name(name)
            body_buf = emit.capture do
              locals = unpack_params(emit, method)
              if method.body
                ExprEmitter.write_body(emit, method.body, locals: locals, last_is_return: true)
              end
              emit.line "return nil_instance();"
            end
            emit.line "virtual BasicObject* #{cpp_name}(Array* args, Hash* kwargs = nullptr, Proc* block = nullptr) {"
            emit.indented { body_buf.each_line { |l| emit.line l.chomp } }
            emit.line "}"
          rescue Cpp::EmissionError => e
            # Skip — falls through to method_missing at runtime.
            $stderr.puts "[box-first] skip user_method :#{name} @ #{method&.source_location.inspect}: #{e.message}" if ENV['FROZONE_BOX_DEBUG'] == '1'
          end

          # C++ reserved words / contextual keywords that surface as
          # Ruby identifier names from time to time (the most common
          # ones in core/4.0/). When a Ruby local/param has one of
          # these names, mangle to `rb__<name>__` consistently across
          # all emission sites — `local_cpp_name(:char)` → `rb__char__`.
          CPP_KEYWORDS = %w[
            enum class struct union template operator this namespace
            new delete default public private protected friend virtual
            override final const static extern inline mutable register
            signed unsigned void char short int long float double bool
            auto typedef typename try catch throw decltype constexpr
            return goto switch case break continue if else while do for
          ].to_set.freeze

          def self.local_cpp_name(name)
            s = name.to_s
            CPP_KEYWORDS.include?(s) ? "rb__#{s}__" : s
          end

          # Emit unpack-from-args lines for required positional params,
          # optional positional params (with C++ ternary against
          # args->data.size()), rest collection, and a `Proc* _block =
          # block;` alias (so from_yield's `_block` always resolves).
          # If the user named the block (`&blk`), emit a second alias.
          # Post/kw/kw_rest params raise EmissionError so the method
          # gets gracefully dropped.
          # Universal-protocol parameter names — collisions with these
          # in user param/local names break the body. `args` is the
          # most common collision (any method with `def foo(args, ...)`
          # would emit `BasicObject* args = array_at(args, 0);` —
          # initialiser refers to itself).
          UNIVERSAL_PARAM_NAMES = %w[args kwargs block].to_set.freeze

          def self.unpack_params(emit, method)
            locals = Set.new
            required = method.required_params || []
            required.each_with_index do |p, i|
              raise Cpp::EmissionError, "param name :#{p} collides with universal protocol param" if UNIVERSAL_PARAM_NAMES.include?(p.to_s)
              emit.line "BasicObject* #{local_cpp_name(p)} = array_at(args, #{i});"
              locals << p.to_s
            end
            optional = method.optional_params || []
            optional.each_with_index do |(p, default_node), i|
              raise Cpp::EmissionError, "param name :#{p} collides with universal protocol param" if UNIVERSAL_PARAM_NAMES.include?(p.to_s)
              idx = required.length + i
              default_str = default_node ? emit.cpp.from_expr(default_node, locals) : "nil_instance()"
              emit.line "BasicObject* #{local_cpp_name(p)} = (args->data.size() > #{idx}) ? args->data[#{idx}] : (#{default_str});"
              locals << p.to_s
            end
            if method.post_params && !method.post_params.empty?
              raise Cpp::EmissionError, "method with post-required params not yet supported"
            end
            (method.optional_kw_params || []).each do |(p, default_node)|
              raise Cpp::EmissionError, "kw param :#{p} collides with universal protocol param" if UNIVERSAL_PARAM_NAMES.include?(p.to_s)
              default_str = default_node ? emit.cpp.from_expr(default_node, locals) : "nil_instance()"
              key_lit = emit.cpp.cpp_string_literal(p.to_s)
              emit.line "BasicObject* #{local_cpp_name(p)} = (kwargs ? [&]() -> BasicObject* { auto _it = kwargs->data.find(intern(#{key_lit})); return _it == kwargs->data.end() ? (#{default_str}) : _it->second; }() : (#{default_str}));"
              locals << p.to_s
            end
            (method.required_kw_params || []).each do |p|
              raise Cpp::EmissionError, "kw param :#{p} collides with universal protocol param" if UNIVERSAL_PARAM_NAMES.include?(p.to_s)
              key_lit = emit.cpp.cpp_string_literal(p.to_s)
              emit.line %(BasicObject* #{local_cpp_name(p)} = (kwargs && kwargs->data.find(intern(#{key_lit})) != kwargs->data.end()) ? kwargs->data[intern(#{key_lit})] : ([&]() -> BasicObject* { std::fprintf(stderr, "[box-first] missing required kw arg :#{p}\\n"); std::abort(); }());)
              locals << p.to_s
            end
            if method.kw_rest_param
              raise Cpp::EmissionError, "method with **kw_rest not yet supported"
            end
            if method.rest_param
              name = method.rest_param.to_s
              name = "_rest" if name.empty? || name == "*"
              cpp_name = local_cpp_name(name)
              start_idx = required.length + optional.length
              if name == "args"
                # Collides with the universal `Array* args` parameter.
                # Only safe when rest is the whole args (no preceding
                # positional/optional params); the parameter already
                # IS what the user wants. Otherwise we'd need a slice
                # but can't bind it to `args` without shadowing.
                raise Cpp::EmissionError, "*args after positional params collides with universal args param" if start_idx > 0
              elsif start_idx == 0
                emit.line "BasicObject* #{cpp_name} = args;  // *rest = whole args"
              else
                emit.line "Array* #{cpp_name} = new Array();"
                emit.line "for (std::size_t _i = #{start_idx}; _i < args->data.size(); _i++) {"
                emit.line "  #{cpp_name}->data.push_back(args->data[_i]);"
                emit.line "}"
              end
              locals << name
            end
            emit.line "Proc* _block = block;"
            locals << "_block"
            user_block = user_block_name(method)
            if user_block && user_block != "_block" && user_block != "block"
              emit.line "Proc* #{user_block} = block;"
            end
            locals << user_block if user_block
            # Pre-declare every other local in the method's `locals`
            # list. Without this, locals first-written inside an `if`
            # branch are scoped to that branch, and a sibling branch
            # that reads/writes them produces "not declared" errors.
            # Pre-declaring at method scope mirrors Ruby's behavior
            # (locals are method-scoped, not block-scoped).
            # Also scans the body for LocalVariableWrites so locals
            # whose first write is inside a graceful-degradation-skipped
            # statement still get a declaration (subsequent reads work).
            # Skips names that collide with universal protocol params
            # (`args`, `kwargs`, `block`) — those would shadow the
            # parameter binding.
            reserved = %w[args kwargs block]
            seen_writes = collect_local_writes(method.body)
            ((method.locals || []) + seen_writes.to_a).uniq.each do |name|
              s = name.to_s
              next if s.empty? || locals.include?(s) || reserved.include?(s)
              emit.line "BasicObject* #{local_cpp_name(s)} = nil_instance();"
              locals << s
            end
            locals
          end

          # Walk the method body collecting every LocalVariableWrite
          # name (including ones inside blocks — Ruby leaks block-locals
          # to the enclosing scope when first-written, our model treats
          # them all as method-scope to keep them visible across blocks).
          def self.collect_local_writes(body)
            names = Set.new
            walk = ->(node) {
              return unless node.is_a?(Ast::Node)
              names << node.name.to_s if node.is_a?(Ast::LocalVariableWrite)
              node.children.each { |c| walk.call(c) } if node.respond_to?(:children)
            }
            walk.call(body) if body
            names
          end

          def self.user_block_name(method)
            return nil unless method.block_param
            n = method.block_param.to_s
            (n.empty? || n == "&") ? nil : n
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
