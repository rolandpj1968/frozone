# Method type specialisation for Codegen.
#
# Analyses call sites to determine which methods can have raw Int64/Float64
# overloads, and emits those specialised overloads alongside the generic
# RubyObject version. Also handles:
# - emit_raw_body: emits method body in fully raw (Int64/Float64) context
# - emit_native_block_body: raw emission for block return values
# - emit_native_iter_block: .times/.upto/.downto with raw block params
# - emit_for_loop: native Crystal range loops
#
# Dependencies: calls node_raw_type, emit_raw, infer_local_types (RawEmission),
# contains_assignment? (RawEmission).

module Frozone
  module Compiler
    module CodegenSupport
      module MethodSpecialisation
      # Walk the execute block looking for free calls where ALL args are raw-typed.
      # Populates @gctx.typed_params with {method_name => [:i64/:f64, ...]} for consistent sites.
      def collect_raw_call_sites(execute_block)
        return unless execute_block
        old_typed = @mctx.typed_locals
        @mctx.typed_locals = infer_local_types(execute_block.body)
        raw_calls = Hash.new { |h, k| h[k] = [] }
        walk_raw_free_calls(execute_block.body, raw_calls)
        @mctx.typed_locals = old_typed

        raw_calls.each do |name, call_type_lists|
          next if call_type_lists.empty?
          next unless call_type_lists.all? { |types| types.all? }      # all non-nil
          arities = call_type_lists.map(&:size).uniq
          next unless arities.size == 1                                  # consistent arity
          merged = call_type_lists.reduce { |a, b| a.zip(b).map { |ta, tb| ta == tb ? ta : nil } }
          @gctx.typed_params[name] = merged if merged&.all?
        end
      end

      def walk_raw_free_calls(node, raw_calls)
        return unless node
        if node.is_a?(Ast::MethodCall) && node.receiver_node.nil? && @cc.user_methods.include?(node.name)
          raw_calls[node.name] << (node.arg_nodes || []).map { |a| node_raw_type(a) }
        end
        node.children.each { |c| walk_raw_free_calls(c, raw_calls) }
      end

      # For each method in @gctx.typed_params, tentatively assume same-type return,
      # then verify by walking the method body. Methods that fail verification
      # are removed from both @gctx.typed_params and @gctx.typed_method_returns.
      def collect_typed_method_returns
        return if @gctx.typed_params.empty?
        methods_table = @cc.top_level_scope.methods_table || {}

        # Tentative assignment (allows recursive calls to see a return type during verification)
        @gctx.typed_params.each do |name, param_types|
          @gctx.typed_method_returns[name] = param_types.first if param_types.uniq.size == 1
        end

        to_remove = []
        @gctx.typed_params.each do |name, param_types|
          method = methods_table[name]
          unless method.is_a?(Vm::Method) && method.body
            to_remove << name; next
          end
          # Only specialise methods with purely required params (no optionals/rest/kw)
          req = method.required_params || []
          unless req.size == param_types.size &&
                 method.optional_params.to_a.empty? &&
                 method.rest_param.nil?
            to_remove << name; next
          end

          old_typed = @mctx.typed_locals
          @mctx.typed_locals = req.zip(param_types).to_h
          actual_return = infer_body_return_type(method.body)
          raw_safe = body_all_raw_safe?(method.body)
          @mctx.typed_locals = old_typed

          unless actual_return == @gctx.typed_method_returns[name] && raw_safe
            to_remove << name
          end
        end

        to_remove.each { |n| @gctx.typed_params.delete(n); @gctx.typed_method_returns.delete(n) }
      end

      # Returns the raw Crystal type (:i64/:f64) of the last expression in a body,
      # or nil if it cannot be determined or is not a raw numeric type.
      def infer_body_return_type(body)
        return nil unless body
        case body
        when Ast::Sequence then infer_body_return_type(body.nodes.last)
        when Ast::If
          t = infer_body_return_type(body.then_node)
          e = infer_body_return_type(body.else_node)
          (t && t == e) ? t : nil
        when Ast::Return then infer_body_return_type(body.value_node)
        else node_raw_type(body)
        end
      end

      # Returns true iff the entire body can be emitted in "raw mode" without
      # boxing — i.e., every sub-expression is either a raw literal/local, an
      # arithmetic/comparison op, or a call to another specialised method.
      def body_all_raw_safe?(node)
        return true unless node
        case node
        when Ast::IntegerLiteral, Ast::FloatLiteral, Ast::NilLiteral,
             Ast::TrueLiteral, Ast::FalseLiteral then true
        when Ast::LocalVariableRead then true
        when Ast::LocalVariableWrite then body_all_raw_safe?(node.value_node)
        when Ast::Sequence then node.nodes.all? { |n| body_all_raw_safe?(n) }
        when Ast::Return then body_all_raw_safe?(node.value_node)
        when Ast::If
          body_all_raw_safe?(node.pred_node) &&
            body_all_raw_safe?(node.then_node) &&
            body_all_raw_safe?(node.else_node)
        when Ast::MethodCall
          name = node.name
          recv = node.receiver_node
          args = node.arg_nodes || []
          if recv.nil?
            # Free call — must be to a specialised method
            @gctx.typed_method_returns.key?(name) ? args.all? { |a| body_all_raw_safe?(a) } : false
          elsif (RawEmission::ARITH_OPS_UNBOX | CrystalEmitter::COMPARE_OPS).include?(name) && args.size == 1
            body_all_raw_safe?(recv) && body_all_raw_safe?(args[0])
          else
            false
          end
        else false
        end
      end

      # Emit a Crystal method with raw Int64/Float64 param and return types.
      # Only called when @gctx.typed_params[name] and @gctx.typed_method_returns[name] are set.
      def emit_specialized_vm_method(name, method)
        param_types = @gctx.typed_params[name]
        return_type = @gctx.typed_method_returns[name]
        req_params = method.required_params || []
        return unless req_params.size == param_types.size

        cr = { i64: 'Int64', f64: 'Float64' }
        parts = req_params.zip(param_types).map { |p, ty| "#{crystal_local(p)} : #{cr[ty]}" }

        write "def #{crystal_method_name(name)}(#{parts.join(', ')}) : #{cr[return_type]}"
        emit_newline

        old_typed = @mctx.typed_locals
        old_typed_arr = @mctx.typed_array_locals
        param_set = req_params.to_set
        # Start with param types, add TI-inferred locals, then infer from literals.
        @mctx.typed_locals = req_params.zip(param_types).to_h
        (@gctx.locals[name] || {}).each do |lname, ty|
          @mctx.typed_locals[lname] = ty unless param_set.include?(lname)
        end
        # Infer types from literal assignments for locals TI didn't cover
        infer_local_types(method.body).each do |lname, ty|
          @mctx.typed_locals[lname] ||= ty unless param_set.include?(lname)
        end
        # Populate typed array locals from TI (non-param only).
        @mctx.typed_array_locals = (@gctx.arrays[name] || {}).reject { |k, _| param_set.include?(k) }
        indented { emit_raw_expr(method.body) }
        @mctx.typed_locals = old_typed
        @mctx.typed_array_locals = old_typed_arr

        emit_newline
        emit_indent
        write "end"
      end

      # Emit a specialized (typed) class method overload.
      # Like emit_specialized_vm_method but with `def self.` prefix and
      # class-keyed TI lookups.
      def emit_specialized_class_method(class_name, mname, method, raw_types, return_type, crystal_param_types: nil)
        req_params = method.required_params || []
        return unless req_params.size == raw_types.size

        cr = { i64: 'Int64', f64: 'Float64' }
        parts = req_params.each_with_index.map do |p, i|
          if raw_types[i]
            "#{crystal_local(p)} : #{cr[raw_types[i]]}"
          elsif crystal_param_types && crystal_param_types[i] && crystal_param_types[i] != :ruby_object
            "#{crystal_local(p)} : #{CrystalType.to_crystal(crystal_param_types[i])}"
          else
            "#{crystal_local(p)} : RubyObject"
          end
        end

        # Include optional kwargs with default values (semi-positional kwargs).
        # Emit as typed Crystal params so the body can reference them.
        opt_kw = method.optional_kw_params || []
        opt_kw.each do |kw_name, default_node|
          default_val = case default_node
                        when Ast::IntegerLiteral then "#{default_node.value.raw}_i64"
                        when Ast::FloatLiteral then float_bits_expr(default_node.value.respond_to?(:raw) ? default_node.value.raw : default_node.value)
                        else "RubyInteger.new(0_i64)"
                        end
          # Check if TI inferred a type for this kwarg
          mkey_for_kw = [class_name, mname]
          kw_ty = @gctx.inferred_kw_params.dig(mkey_for_kw, kw_name) || @gctx.inferred_kw_params.dig(mname, kw_name)
          if kw_ty && cr[kw_ty]
            parts << "#{crystal_local(kw_name)} : #{cr[kw_ty]} = #{default_val}"
          else
            parts << "#{crystal_local(kw_name)} : Int64 = #{default_val}"
          end
        end

        write "def self.#{crystal_method_name(mname)}(#{parts.join(', ')})"
        # Only annotate return type when all positional params are raw-typed
        write " : #{cr[return_type]}" if return_type && raw_types.all?
        emit_newline

        old_typed = @mctx.typed_locals
        old_typed_arr = @mctx.typed_array_locals
        old_class_name = @cctx.name
        @cctx.name = class_name
        param_set = req_params.to_set
        mkey = [class_name, mname]
        # Start with param types
        @mctx.typed_locals = {}
        req_params.zip(raw_types).each { |p, ty| @mctx.typed_locals[p] = ty if ty }
        # Kwargs are also typed locals in the raw context
        opt_kw.each do |kw_name, _|
          mkey_for_kw = [class_name, mname]
          kw_ty = @gctx.inferred_kw_params.dig(mkey_for_kw, kw_name) || @gctx.inferred_kw_params.dig(mname, kw_name)
          @mctx.typed_locals[kw_name] = kw_ty if kw_ty && (kw_ty == :i64 || kw_ty == :f64)
        end
        # Class-typed locals for devirtualisation
        @mctx.class_locals = @gctx.class_locals[mkey] || @gctx.class_locals[mname] || {}
        # Add TI-inferred locals
        (@gctx.locals[mkey] || @gctx.locals[mname] || {}).each do |lname, ty|
          @mctx.typed_locals[lname] = ty unless param_set.include?(lname)
        end
        infer_local_types(method.body).each do |lname, ty|
          @mctx.typed_locals[lname] ||= ty unless param_set.include?(lname)
        end
        @mctx.typed_array_locals = (@gctx.arrays[mkey] || @gctx.arrays[mname] || {}).reject { |k, _| param_set.include?(k) }
        # Register Array(Int64)/Array(Float64) params as native arrays
        @mctx.native_array_locals = {}
        if crystal_param_types
          req_params.each_with_index do |p, i|
            pt = crystal_param_types[i]
            if CrystalType.array?(pt) && CrystalType.scalar?(CrystalType.elem(pt))
              @mctx.native_array_locals[p] = CrystalType.elem(pt)
            end
          end
        end
        # Use raw expression emitter for specialized overloads — never boxes
        indented { emit_raw_expr(method.body) }
        @mctx.typed_locals = old_typed
        @mctx.typed_array_locals = old_typed_arr
        @cctx.name = old_class_name

        emit_newline
        emit_indent
        write "end"
      end

      # Emit a block body that may return a boxable raw numeric.
      # Sequences: all-but-last via emit, last via this method (tail-recursive).
      # Single expression: if raw-typed, wrap with RubyFloat/RubyInteger.new.
      def emit_native_block_body(node)
        # Multi-statement sequence: emit all but last normally, last with possible boxing.
        if node.is_a?(Ast::Sequence) && node.nodes.size > 1
          node.nodes[0..-2].each { |n| emit_indent; emit(n); emit_newline }
          emit_native_block_body(node.nodes.last)
          return
        end
        # Single expression (or 1-element Sequence — unwrap it).
        expr = node.is_a?(Ast::Sequence) ? node.nodes.first : node
        emit_indent
        if expr && (rt = node_raw_type(expr))
          box = rt == :f64 ? "RubyFloat" : "RubyInteger"
          write "#{box}.new("; emit_raw(expr); write ")"
        else
          emit(expr || node)
        end
      end

      # Emit a block for native integer iteration (times/upto/downto),
      # registering block params as raw :i64 so arithmetic inside is unboxed.
      def emit_native_iter_block(blk)
        params = (blk.required_params || []) + (blk.optional_params || []).map(&:first)
        params += [blk.rest_param].compact
        write "{ "
        unless params.empty?
          write "|#{params.map { |p| crystal_local(p) }.join(', ')}| "
        end
        old_rbp = @mctx.raw_block_params
        @mctx.raw_block_params = old_rbp.merge(params.map { |p| [p, :i64] }.to_h)
        emit(blk.body)
        @mctx.raw_block_params = old_rbp
        write " }"
      end

      # Override: emit `for i in lo...hi` as a native Crystal integer range loop
      # when the iteration variable is typed :i64 in TI.
      def emit_for_loop(node)
        target = node.target
        if target[0] == :local
          name = target[1]
          if @mctx.block_params[name] == :i64
            coll = node.collection_node
            if coll.is_a?(Ast::RangeLiteral)
              lo = coll.begin_node
              hi = coll.end_node
              excl = coll.exclusive
              if node_raw_type(lo) == :i64 && node_raw_type(hi) == :i64
                write "("
                emit_raw(lo)
                write excl ? "..." : ".."
                emit_raw(hi)
                write ").each do |#{crystal_local(name)}|"
                emit_newline
                old_rbp = @mctx.raw_block_params
                @mctx.raw_block_params = old_rbp.merge(name => :i64)
                indented { emit(node.body_node) }
                @mctx.raw_block_params = old_rbp
                emit_newline
                emit_indent
                write "end"
                return
              end
            end
          end
        end
        super
      end

      end
    end
  end
end
