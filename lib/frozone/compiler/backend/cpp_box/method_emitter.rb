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
          rescue Cpp::EmissionError
            # Skip — falls through to method_missing at runtime.
          end

          # C++ reserved words / contextual keywords that surface as
          # Ruby identifier names from time to time (the most common
          # ones in core/4.0/). Any method whose params or locals
          # collide raises EmissionError → graceful skip.
          CPP_KEYWORDS = %w[
            enum class struct union template operator this namespace
            new delete default public private protected friend virtual
            override final const static extern inline mutable register
            signed unsigned void char short int long float double bool
            auto typedef typename try catch throw decltype constexpr
            return goto switch case break continue if else while do for
          ].to_set.freeze

          # Emit unpack-from-args lines for required positional params,
          # optional positional params (with C++ ternary against
          # args->data.size()), rest collection, and a `Proc* _block =
          # block;` alias (so from_yield's `_block` always resolves).
          # If the user named the block (`&blk`), emit a second alias.
          # Post/kw/kw_rest params raise EmissionError so the method
          # gets gracefully dropped.
          def self.unpack_params(emit, method)
            locals = Set.new
            required = method.required_params || []
            required.each_with_index do |p, i|
              raise Cpp::EmissionError, "param name :#{p} is a C++ reserved word" if CPP_KEYWORDS.include?(p.to_s)
              emit.line "BasicObject* #{p} = array_at(args, #{i});"
              locals << p.to_s
            end
            optional = method.optional_params || []
            optional.each_with_index do |(p, default_node), i|
              raise Cpp::EmissionError, "param name :#{p} is a C++ reserved word" if CPP_KEYWORDS.include?(p.to_s)
              idx = required.length + i
              default_str = default_node ? emit.cpp.from_expr(default_node, locals) : "nil_instance()"
              emit.line "BasicObject* #{p} = (args->data.size() > #{idx}) ? args->data[#{idx}] : (#{default_str});"
              locals << p.to_s
            end
            if method.post_params && !method.post_params.empty?
              raise Cpp::EmissionError, "method with post-required params not yet supported"
            end
            if (method.required_kw_params && !method.required_kw_params.empty?) ||
               (method.optional_kw_params && !method.optional_kw_params.empty?) ||
               method.kw_rest_param
              raise Cpp::EmissionError, "method with kw params not yet supported"
            end
            if method.rest_param
              name = method.rest_param.to_s
              name = "_rest" if name.empty? || name == "*"
              raise Cpp::EmissionError, "rest_param :#{name} is a C++ reserved word" if CPP_KEYWORDS.include?(name)
              start_idx = required.length + optional.length
              if name == "args"
                # Collides with the universal `Array* args` parameter.
                # Only safe when rest is the whole args (no preceding
                # positional/optional params); the parameter already
                # IS what the user wants. Otherwise we'd need a slice
                # but can't bind it to `args` without shadowing.
                raise Cpp::EmissionError, "*args after positional params collides with universal args param" if start_idx > 0
              elsif start_idx == 0
                emit.line "BasicObject* #{name} = args;  // *rest = whole args"
              else
                emit.line "Array* #{name} = new Array();"
                emit.line "for (std::size_t _i = #{start_idx}; _i < args->data.size(); _i++) {"
                emit.line "  #{name}->data.push_back(args->data[_i]);"
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
            # Skip names that collide with universal protocol params
            # (`args`, `kwargs`, `block`) — those would shadow the
            # parameter binding.
            reserved = %w[args kwargs block]
            (method.locals || []).each do |name|
              s = name.to_s
              next if s.empty? || locals.include?(s) || reserved.include?(s)
              raise Cpp::EmissionError, "local :#{s} is a C++ reserved word" if CPP_KEYWORDS.include?(s)
              emit.line "BasicObject* #{s} = nil_instance();"
              locals << s
            end
            locals
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
