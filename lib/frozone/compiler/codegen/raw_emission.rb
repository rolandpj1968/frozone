# Raw/typed emission helpers for Codegen.
#
# Provides the core unboxed emission pipeline:
# - node_raw_type: determines if an AST node has a provable bare Crystal type
# - infer_local_types: fixed-point inference from literal assignments
# - emit_raw: emit a node as bare Int64/Float64 (no RubyObject wrapping)
# - emit_as: coerce a node to a target raw type
# - emit_coerce_i64/f64: coerce with assignment-aware parens
#
# Dependencies: calls native_array_elem_type (ArrayAnalysis),
# emit/write/crystal_local/ivar (CrystalEmitter).

module Frozone
  module Compiler
    module CodegenSupport
      module RawEmission
      ARITH_OPS_UNBOX = %i[+ - * ** / % | & ^ << >>].to_set

      # Immutable type context for functional raw emission.
      # Passed through raw_lines/node_raw_type instead of reading mutable @mctx.
      RawCtx = Struct.new(:typed_locals, :raw_block_params, :class_locals,
                          :local_array_elems, :typed_array_locals,
                          :native_array_locals, :ivars, keyword_init: true)

      def build_raw_ctx
        RawCtx.new(
          typed_locals: @mctx.typed_locals.dup.freeze,
          raw_block_params: @mctx.raw_block_params.dup.freeze,
          class_locals: (@mctx.class_locals || {}).dup.freeze,
          local_array_elems: (@mctx.local_array_elems || {}).dup.freeze,
          typed_array_locals: (@mctx.typed_array_locals || {}).dup.freeze,
          native_array_locals: (@mctx.native_array_locals || {}).dup.freeze,
          ivars: (@cctx&.ivars || {}).dup.freeze
        ).freeze
      end

      def accessor_method_name?(name) = @cctx.name && @gctx.typed_ivars.fetch(@cctx.name, {})[:"@#{name}"]
      def coerce_f64(node) = raw_as(node, Type::F64)
      def emit_coerce_f64(node) = write coerce_f64(node)
      def raw_args(args, ctx = nil) = args.map { |a| raw(a, ctx) }.join(", ")
      def emit_raw_args(args) = write raw_args(args)

      # Returns Type::I64, Type::F64, or nil for the provable bare Crystal type of a node.
      # ctx: RawCtx (immutable) — pass explicitly for functional paths, or omit for
      # backward compat (builds from mutable @mctx/@cctx).
      def node_raw_type(node, ctx = nil)
        return nil unless node
        ctx ||= build_raw_ctx
        case node
        when Ast::IntegerLiteral then Type::I64
        when Ast::FloatLiteral then Type::F64
        when Ast::Sequence then node_raw_type(node.nodes.last, ctx) if node.nodes.any?
        when Ast::LocalVariableRead
          ctx.typed_locals[node.name] || ctx.raw_block_params[node.name]
        when Ast::LocalVariableWrite
          node_raw_type(node.value_node, ctx)
        when Ast::InstanceVariableRead
          ctx.ivars[node.name]
        when Ast::ConstantRead
          @gctx.const_raw_types[node.name]
        when Ast::ConstantPath
          parent = node.parent_node
          Type::F64 if parent.is_a?(Ast::ConstantRead) && parent.name == :Math
        when Ast::MethodCall
          node_raw_type_call(node, ctx)
        when Ast::IndexOperatorWrite
          recv = node.receiver_node
          native_array_elem_type(recv.name, ctx) if recv.is_a?(Ast::LocalVariableRead)
        else nil
        end
      end

      def node_raw_type_call(node, ctx)
        name = node.name
        recv = node.receiver_node
        args = node.arg_nodes || []
        return @gctx.typed_method_returns[name] if recv.nil? && @gctx.typed_method_returns[name]
        return @gctx.instance_method_raw_returns[[@cctx.name, name]] if recv.nil? && @cctx.name && @gctx.instance_method_raw_returns[[@cctx.name, name]]
        return Type::F64 if recv.is_a?(Ast::ConstantRead) && recv.name == :Math
        if recv.is_a?(Ast::LocalVariableRead)
          recv_class = ctx.class_locals[recv.name]
          return @gctx.instance_method_raw_returns[[recv_class, name]] if recv_class && @gctx.instance_method_raw_returns[[recv_class, name]]
        end
        if name == :[] && args.size == 1 && recv.is_a?(Ast::LocalVariableRead)
          nat_ty = native_array_elem_type(recv.name, ctx) and return nat_ty
          elem_ty = ctx.local_array_elems[recv.name] and return elem_ty
        end
        return Type::I64 if (name == :succ || name == :pred) && args.empty? && node_raw_type(recv, ctx)&.i64?
        return Type::F64 if %i[to_f to_f64].include?(name) && args.empty? && recv
        return Type::I64 if %i[to_i to_i64].include?(name) && args.empty? && recv
        return nil unless ARITH_OPS_UNBOX.include?(name) && args.size == 1
        rt = node_raw_type(recv, ctx)
        at = node_raw_type(args[0], ctx)
        (rt && at) ? ((rt.f64? || at.f64?) ? Type::F64 : Type::I64) : nil
      end

      # Infer which method-body locals can be emitted as bare Int64/Float64.
      #
      # Two-phase fixed-point:
      #   1. Seed from literal assignments (IntegerLiteral → :i64, FloatLiteral → :f64).
      #   2. Expand: promote any un-typed local whose ALL assignments are provably typed
      #      (handles propagation like `_iopw_i0 = j` when j is already typed).
      #   3. Narrow: evict any local whose assignments are not all consistent with its type.
      #   4. Repeat 2-3 until stable.
      def infer_local_types(body)
        return {} unless body
        assignments = Hash.new { |h, k| h[k] = [] }
        collect_local_assignments(body, assignments)
        return {} if assignments.empty?

        old_typed = @mctx.typed_locals

        # Phase 1: seed from literals (unwrap chained assignments)
        @mctx.typed_locals = {}
        assignments.each do |name, nodes|
          nodes.each do |n|
            # Unwrap chained assignments: sum = maxflips = 0 → IntegerLiteral
            inner = n
            inner = inner.value_node while inner.is_a?(Ast::LocalVariableWrite)
            case inner
            when Ast::IntegerLiteral then @mctx.typed_locals[name] ||= Type::I64
            when Ast::FloatLiteral then @mctx.typed_locals[name] = Type::F64
            end
          end
        end

        # Phase 2+3: expand then narrow until fixpoint
        loop do
          prev = @mctx.typed_locals.dup

          # Expand: type any local whose assignments are all uniformly typed
          assignments.each do |name, nodes|
            next if @mctx.typed_locals[name]
            types = nodes.map { |n| node_raw_type(n) }
            next if types.any?(&:nil?)
            unique = types.uniq
            @mctx.typed_locals[name] = unique[0] if unique.size == 1
          end

          # Narrow: evict any local with an inconsistent assignment
          assignments.each do |name, nodes|
            next unless (ty = @mctx.typed_locals[name])
            ok = nodes.all? do |n|
              nt = node_raw_type(n)
              nt == ty || (ty.f64? && nt&.i64?)
            end
            @mctx.typed_locals.delete(name) unless ok
          end

          break if @mctx.typed_locals == prev
        end

        result = @mctx.typed_locals
        @mctx.typed_locals = old_typed
        result
      end

      # Walk a body AST collecting all LocalVariableWrite RHS nodes per name.
      # Does not descend into block bodies (block params share Ruby scope but
      # may receive heterogeneous types from the block caller).
      def collect_local_assignments(node, result)
        return unless node
        if node.is_a?(Ast::LocalVariableWrite)
          result[node.name] << node.value_node
        end
        node.children.each do |c|
          collect_local_assignments(c, result) unless c.is_a?(Ast::Block)
        end
      end

      # Return a bare Crystal numeric string (Int64 or Float64) for a node.
      # Only call when node_raw_type(node, ctx) is non-nil.
      # Returns String — callers write the result.
      def raw(node, ctx = nil)
        case node
        when Ast::And then "(#{raw(node.left_node)} && #{raw(node.right_node)})"
        when Ast::Or  then "(#{raw(node.left_node)} || #{raw(node.right_node)})"
        when Ast::IntegerLiteral then "#{node.value.raw}_i64"
        when Ast::FloatLiteral
          val = node.value.respond_to?(:raw) ? node.value.raw : node.value
          float_bits_expr(val)
        when Ast::Sequence
          nodes = node.nodes
          if nodes.size == 1
            raw(nodes.first)
          else
            parts = nodes.each_with_index.map { |n, i| i == nodes.size - 1 ? raw(n) : capture { emit(n) } }
            "(#{parts.join('; ')})"
          end
        when Ast::LocalVariableRead then crystal_local(node.name)
        when Ast::InstanceVariableRead then node.name.to_s
        when Ast::ConstantRead
          ty = @gctx.const_raw_types[node.name]
          s = capture { emit_constant_read(node) }
          (ty.nil? || ty == Type::ARRAY_I64 || ty == Type::ARRAY_F64) ? s : "#{s}#{ty.f64? ? '.to_f64' : '.to_i64'}"
        when Ast::ConstantPath
          parent = node.parent_node
          (parent.is_a?(Ast::ConstantRead) && parent.name == :Math) ? "Math::#{node.name}" : "#{capture { emit(node) }}.to_f64"
        when Ast::MethodCall then raw_call(node, ctx)
        else capture { emit(node) }
        end
      end

      # Backward compat — imperative callers that expect write side effect.
      def emit_raw(node) = write raw(node)

      # Emit a MethodCall node as bare Crystal numeric in raw context.
      # Return Crystal source for a MethodCall in raw context.
      def raw_call(node, ctx)
        name = node.name
        recv = node.receiver_node
        args = node.arg_nodes || []
        raw_coercion(name, recv, ctx) ||
          raw_succ_pred(name, recv, ctx) ||
          raw_array_read(name, recv, args, node, ctx) ||
          raw_self_accessor(name, recv, ctx) ||
          raw_typed_free_call(name, recv, args, node, ctx) ||
          raw_class_instance_call(name, recv, ctx) ||
          raw_math_call(name, recv, args, ctx) ||
          raw_arithmetic(name, recv, args, ctx) ||
          raw_call_fallback(node, name, recv, ctx)
      end

      def raw_coercion(name, recv, ctx)
        return unless recv
        if %i[to_f to_f64].include?(name) then node_raw_type(recv, ctx)&.f64? ? raw(recv, ctx) : "#{raw(recv, ctx)}.to_f64"
        elsif %i[to_i to_i64].include?(name) then node_raw_type(recv, ctx)&.i64? ? raw(recv, ctx) : "#{raw(recv, ctx)}.to_i64"
        end
      end

      def raw_succ_pred(name, recv, ctx)
        return unless (name == :succ || name == :pred) && node_raw_type(recv, ctx)&.i64?
        "(#{raw(recv, ctx)} #{name == :succ ? '+ 1_i64' : '- 1_i64'})"
      end

      def raw_array_read(name, recv, args, node, ctx)
        return unless name == :[] && args.size == 1 && recv.is_a?(Ast::LocalVariableRead)
        arr_name = recv.name
        idx = capture { emit_coerce_i64(args[0]) }
        if native_array_elem_type(arr_name)
          "#{crystal_local(arr_name)}[#{idx}]"
        elsif (elem_ty = @mctx.local_array_elems[arr_name])
          cast = elem_ty.f64? ? ".as(RubyFloat).to_f64" : ".as(RubyInteger).to_i64"
          "#{crystal_local(arr_name)}[#{idx}]#{cast}"
        else
          capture { emit(node) }
        end
      end

      def raw_self_accessor(name, recv, ctx)
        return unless recv.nil? && @cctx.name &&
          @gctx.instance_method_raw_returns[[@cctx.name, name]] && accessor_method_name?(name)
        "#{crystal_method_name(name)}_raw"
      end

      def raw_typed_free_call(name, recv, args, node, ctx)
        return unless recv.nil? && @gctx.typed_params[name]
        s = "#{crystal_method_name(name)}(#{args.map { |a| raw(a, ctx) }.join(', ')})"
        unless @gctx.typed_method_returns[name]
          ret = node_raw_type(node, ctx)
          s += (ret&.f64? ? ".to_f64" : ".to_i64") if ret
        end
        s
      end

      def raw_class_instance_call(name, recv, ctx)
        return unless recv.is_a?(Ast::LocalVariableRead)
        recv_class = @mctx.class_locals[recv.name] or return
        @gctx.instance_method_raw_returns[[recv_class, name]] or return
        "#{raw(recv, ctx)}.as(Ruby_#{crystal_constant(recv_class)}).#{crystal_method_name(name)}_raw"
      end

      def raw_math_call(name, recv, args, ctx)
        return unless recv.is_a?(Ast::ConstantRead) && recv.name == :Math &&
          args.size >= 1 && args.all? { |a| node_raw_type(a, ctx) }
        "Math.#{name}(#{args.map { |a| raw(a, ctx) }.join(', ')})"
      end

      def raw_arithmetic(name, recv, args, ctx)
        return unless (ARITH_OPS_UNBOX | CrystalEmitter::COMPARE_OPS).include?(name) && args.size == 1 && recv
        ty = (node_raw_type(recv, ctx)&.f64? || node_raw_type(args[0])&.f64?) ? Type::F64 : Type::I64
        op = (name == :/ && ty.i64?) ? "//" : name.to_s
        "(#{raw_as(recv, ty, ctx)} #{op} #{raw_as(args[0], ty, ctx)})"
      end

      def raw_call_fallback(node, name, recv, ctx)
        s = capture { emit(node) }
        ret = @gctx.typed_method_returns[name] if recv.nil?
        ret ? "#{s}#{ret.f64? ? '.to_f64' : '.to_i64'}" : s
      end

      # Return Crystal source for node coerced to the given raw type.
      def raw_as(node, ty, ctx = nil)
        nt = node_raw_type(node, ctx)
        return raw(node, ctx) if nt == ty
        return "#{raw(node, ctx)}.to_f64" if nt&.i64? && ty.f64?
        # Recurse into arithmetic with at least one typed operand
        if node.is_a?(Ast::MethodCall)
          name = node.name
          recv = node.receiver_node
          args = node.arg_nodes || []
          if (ARITH_OPS_UNBOX | CrystalEmitter::COMPARE_OPS).include?(name) && args.size == 1 && recv
            rt = node_raw_type(recv, ctx)
            at = node_raw_type(args[0])
            if rt || at
              op = (name == :/ && ty.i64?) ? "//" : name.to_s
              return "(#{raw_as(recv, ty, ctx)} #{op} #{raw_as(args[0], ty, ctx)})"
            end
          end
        end
        # Fallback: emit boxed and coerce.
        s = capture { emit(node) }
        s = "(#{s})" if contains_assignment?(node)
        "#{s}#{ty.f64? ? '.to_f64' : '.to_i64'}"
      end

      # Backward compat — imperative callers.
      def emit_as(node, ty) = write raw_as(node, ty)

      def coerce_i64(node) = raw_as(node, Type::I64)
      def emit_coerce_i64(node) = write coerce_i64(node)

      # Does this node contain an assignment that needs parens when used as an
      # operand? Handles Sequence([LocalVariableWrite]) from parser grouping.
      def contains_assignment?(node)
        return true if node.is_a?(Ast::LocalVariableWrite) || node.is_a?(Ast::InstanceVariableWrite)
        return true if node.is_a?(Ast::IndexOperatorWrite) || node.is_a?(Ast::AttributeWrite)
        node.is_a?(Ast::Sequence) && node.nodes.size == 1 && contains_assignment?(node.nodes.first)
      end

      # -----------------------------------------------------------------------
      # raw_lines — pure functional raw expression emitter.
      # Returns Array<String> (lines of Crystal source, no trailing newlines).
      # Never boxes. Falls back to capture { emit(node) } for inherently
      # RubyObject-valued nodes (string literals, hash literals, etc.)
      # -----------------------------------------------------------------------

      def indent(lines) = lines.map { |l| "  #{l}" }

      def raw_lines(node, ctx = nil)
        ctx ||= build_raw_ctx
        case node
        when Ast::IntegerLiteral then ["#{node.value.raw}_i64"]
        when Ast::FloatLiteral
          val = node.value.respond_to?(:raw) ? node.value.raw : node.value
          [float_bits_expr(val)]
        when Ast::NilLiteral then ["RUBY_NIL"]
        when Ast::TrueLiteral then ["true"]
        when Ast::FalseLiteral then ["false"]
        when Ast::LocalVariableRead then [crystal_local(node.name)]
        when Ast::InstanceVariableRead then [node.name.to_s]
        when Ast::ConstantRead then ["Ruby_#{crystal_constant(node.name)}"]
        when Ast::ConstantPath
          parent = node.parent_node
          [(parent.is_a?(Ast::ConstantRead) && parent.name == :Math) ? "Math::#{node.name}" : capture { emit(node) }]
        when Ast::And then ["(#{raw_lines(node.left_node, ctx).join} && #{raw_lines(node.right_node, ctx).join})"]
        when Ast::Or  then ["(#{raw_lines(node.left_node, ctx).join} || #{raw_lines(node.right_node, ctx).join})"]
        when Ast::Sequence then node.nodes.flat_map { |n| raw_lines(n, ctx) }
        when Ast::If then raw_lines_if(node, ctx)
        when Ast::Return then node.value_node ? ["return #{raw_lines(node.value_node, ctx).join}"] : ["return"]
        when Ast::LocalVariableWrite then raw_lines_local_write(node, ctx)
        when Ast::AttributeWrite then raw_lines_attr_write(node, ctx)
        when Ast::MethodCall then raw_lines_method_call(node, ctx)
        else [capture { emit(node) }]
        end
      end

      def raw_lines_if(node, ctx)
        then_ty = node_raw_type(node.then_node, ctx)
        else_ty = node.else_node ? node_raw_type(node.else_node, ctx) : nil
        needs_float = (then_ty&.f64? && else_ty&.i64?) || (then_ty&.i64? && else_ty&.f64?)
        then_lines = raw_lines(node.then_node, ctx)
        then_lines[-1] += ".to_f64" if needs_float && then_ty&.i64? && then_lines.any?
        lines = ["if #{raw_truthy(node.pred_node, ctx)}", *indent(then_lines)]
        if node.else_node
          else_lines = raw_lines(node.else_node, ctx)
          else_lines[-1] += ".to_f64" if needs_float && else_ty&.i64? && else_lines.any?
          lines.push("else", *indent(else_lines))
        end
        lines << "end"
      end

      def raw_lines_local_write(node, ctx)
        name = node.name
        # Delegate array construction to specialised handlers (still imperative)
        handled = capture {
          try_nested_array_write(node, name) || try_range_to_a_write(node, name) ||
            try_native_dup_write(node, name) || try_typed_array_write(node, name) ||
            try_boxed_array_promote(node, name)
        }
        return [handled] unless handled.empty?
        val = raw_lines(node.value_node, ctx)
        if val.size == 1
          ["#{crystal_local(name)} = #{val[0]}"]
        else
          ["#{crystal_local(name)} = begin", *indent(val), "end"]
        end
      end

      def raw_lines_attr_write(node, ctx)
        recv = node.receiver_node
        if node.name == :[]= && recv.is_a?(Ast::InstanceVariableRead)
          iv_ty = @cctx&.ivars&.dig(recv.name)
          if iv_ty == Type::ARRAY_F64 || iv_ty == Type::ARRAY_I64
            args = node.arg_nodes
            return ["#{recv.name}[#{raw_lines(args[0], ctx).join}] = #{raw_lines(args[1], ctx).join}"]
          end
        end
        [capture { emit(node) }]
      end

      def raw_lines_method_call(node, ctx)
        result = raw_expr_call(node, ctx)
        result ? [result] : [capture { emit(node) }]
      end

      # Backward compat — imperative callers write raw_lines to buffer.
      def emit_raw_expr(node)
        lines = raw_lines(node)
        lines.each_with_index do |line, i|
          emit_indent if i > 0
          write line
          emit_newline if i < lines.size - 1
        end
      end

      # Emit a truthy check in raw context — use native Crystal booleans
      def raw_truthy(node, ctx = nil)
        if node.is_a?(Ast::MethodCall) &&
           (ARITH_OPS_UNBOX | CrystalEmitter::COMPARE_OPS).include?(node.name) &&
           node.receiver_node && (node.arg_nodes || []).size == 1
          "(#{raw_lines(node.receiver_node).join} #{node.name} #{raw_lines(node.arg_nodes[0]).join})"
        elsif node.is_a?(Ast::And)
          "(#{raw_truthy(node.left_node, ctx)} && #{raw_truthy(node.right_node, ctx)})"
        elsif node.is_a?(Ast::Or)
          "(#{raw_truthy(node.left_node, ctx)} || #{raw_truthy(node.right_node, ctx)})"
        else
          raw_lines(node).join("\n")
        end
      end

      def emit_raw_truthy(node) = write raw_truthy(node)

      # Try to emit a method call in raw mode. Returns true if handled.
      # Try to produce Crystal source for a method call in raw_expr context.
      # Returns String or nil (unhandled — caller falls back to emit).
      def raw_expr_call(node, ctx)
        name = node.name
        recv = node.receiver_node
        args = node.arg_nodes || []
        raw_expr_math(name, recv, args, ctx) ||
          raw_expr_arith(name, recv, args, ctx) ||
          raw_expr_coerce(name, recv, ctx) ||
          raw_expr_unary(name, recv, ctx) ||
          raw_expr_numeric_method(name, recv, ctx) ||
          raw_expr_module_call(name, recv, args, node, ctx) ||
          raw_expr_min_max(name, recv, args, ctx) ||
          raw_expr_free_call(name, recv, args, node, ctx) ||
          raw_expr_instance_call(name, recv, args, node, ctx)
      end

      def raw_expr_math(name, recv, args, ctx)
        return unless recv.is_a?(Ast::ConstantRead) && recv.name == :Math
        "Math.#{name}(#{expr_args(args, ctx)})"
      end

      def raw_expr_arith(name, recv, args, ctx)
        return unless (ARITH_OPS_UNBOX | CrystalEmitter::COMPARE_OPS).include?(name) && args.size == 1 && recv
        op = (name == :/ && node_raw_type(recv, ctx)&.i64? && node_raw_type(args[0])&.i64?) ? "//" : name.to_s
        "(#{raw_lines(recv, ctx).join} #{op} #{raw_lines(args[0], ctx).join})"
      end

      def raw_expr_coerce(name, recv, ctx)
        return unless recv
        s = raw_lines(recv, ctx).join
        if %i[to_f to_f64].include?(name) then "#{s}.to_f64"
        elsif %i[to_i to_i64].include?(name) then "#{s}.to_i64"
        end
      end

      def raw_expr_unary(name, recv, ctx)
        return unless recv
        s = raw_lines(recv, ctx).join
        if name == :-@ then "(-#{s})"
        elsif name == :+@ then s
        end
      end

      def raw_expr_numeric_method(name, recv, ctx)
        return unless %i[abs floor ceil round].include?(name) && recv
        s = "#{raw_lines(recv, ctx).join}.#{name}"
        s += ".to_i64" if %i[floor ceil round].include?(name) && node_raw_type(recv, ctx)&.f64?
        s
      end

      def raw_expr_module_call(name, recv, args, node, ctx)
        return unless recv.is_a?(Ast::ConstantRead)
        cr_type = CrystalEmitter::RUBY_TO_CRYSTAL_TYPE[recv.name] || "Ruby_#{crystal_constant(recv.name)}"
        arg_str = (name == :new && CrystalEmitter::RUBY_TO_CRYSTAL_TYPE.key?(recv.name)) ?
          args.map { |a| capture { emit(a) } }.join(", ") : expr_args(args, ctx)
        "#{cr_type}.#{crystal_method_name(name)}(#{arg_str})#{raw_block(node, ctx)}"
      end

      def raw_expr_min_max(name, recv, args, ctx)
        return unless (name == :min || name == :max) && args.size == 2 && (recv.nil? || recv.is_a?(Ast::SelfLiteral))
        "Math.#{name}(#{expr_args(args, ctx)})"
      end

      def raw_expr_free_call(name, recv, args, node, ctx)
        return unless recv.nil? || recv.is_a?(Ast::SelfLiteral)
        mkey = @cctx&.name ? [@cctx.name, name] : name
        raw_params = @gctx.class_params&.dig(mkey) || @gctx.typed_params&.dig(name)
        has_typed = raw_params&.any? { |t| t&.raw? }
        prefix = recv.is_a?(Ast::SelfLiteral) ? "self." : ""
        arg_str = if has_typed
          args.each_with_index.map { |a, i|
            s = raw_lines(a, ctx).join
            pty = (raw_params && i < raw_params.size) ? raw_params[i] : nil
            s += ".to_i64" if pty&.i64?
            s += ".to_f64" if pty&.f64?
            s
          }.join(", ")
        else
          args.map { |a| capture { emit(a) } }.join(", ")
        end
        s = "#{prefix}#{crystal_method_name(name)}(#{arg_str})#{raw_block(node, ctx)}"
        unless has_typed
          ret = node_raw_type(node, ctx)
          s += (ret&.f64? ? ".to_f64" : ".to_i64") if ret
        end
        s
      end

      def raw_expr_instance_call(name, recv, args, node, ctx)
        return unless recv.is_a?(Ast::LocalVariableRead)
        recv_name = recv.name
        return unless @mctx.typed_locals[recv_name] || @mctx.class_locals&.dig(recv_name) || @mctx.native_array_locals&.dig(recv_name)
        s = "#{crystal_local(recv_name)}.#{crystal_method_name(name)}(#{expr_args(args, ctx)})"
        recv_cls = @mctx.class_locals&.dig(recv_name)
        recv_cls = recv_cls.is_a?(Array) ? recv_cls[0] : recv_cls
        if recv_cls && (ret = @gctx.instance_method_raw_returns&.dig([recv_cls, name]))
          s += ret.f64? ? ".to_f64" : ".to_i64"
        end
        "#{s}#{raw_block(node, ctx)}"
      end

      def expr_args(args, ctx) = args.map { |a| raw_lines(a, ctx).join }.join(", ")

      # Block in raw context → inline string suffix. Single-line body only.
      def raw_block(node, ctx)
        blk = node.block_node
        return "" unless blk.is_a?(Ast::Block)
        params = blk.required_params || []
        param_str = params.empty? ? "" : "|#{params.map { |p| crystal_local(p) }.join(', ')}| "
        body_lines = blk.body ? raw_lines(blk.body) : []
        if body_lines.size <= 1
          " { #{param_str}#{body_lines.first || ''} }"
        else
          " do#{params.empty? ? '' : " |#{params.map { |p| crystal_local(p) }.join(', ')}|"}\n#{indent(body_lines).join("\n")}\nend"
        end
      end

      end
    end
  end
end
