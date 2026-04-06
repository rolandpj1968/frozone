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

      # Is this method name a simple accessor (getter for a typed ivar)?
      def accessor_method_name?(name) = @cctx.name && @gctx.typed_ivars.fetch(@cctx.name, {})[:"@#{name}"]
      def coerce_f64(node) = raw_as(node, Type::F64)
      def emit_coerce_f64(node) = write coerce_f64(node)
      def raw_args(args) = args.map { |a| raw(a) }.join(", ")
      def emit_raw_args(args) = write raw_args(args)

      # Returns Type::I64, Type::F64, or nil for the provable bare Crystal type of a node.
      def node_raw_type(node)
        return nil unless node
        case node
        when Ast::IntegerLiteral then Type::I64
        when Ast::FloatLiteral then Type::F64
        when Ast::Sequence then node_raw_type(node.nodes.last) if node.nodes.any?
        when Ast::LocalVariableRead
          @mctx.typed_locals[node.name] || @mctx.raw_block_params[node.name]
        when Ast::LocalVariableWrite
          # Chained assignment: sum = maxflips = 0 — type is the inner value's type
          node_raw_type(node.value_node)
        when Ast::InstanceVariableRead
          @cctx.ivars[node.name]
        when Ast::ConstantRead
          @gctx.const_raw_types[node.name]
        when Ast::ConstantPath
          # Math::PI, Math::E → Type::F64
          parent = node.parent_node
          if parent.is_a?(Ast::ConstantRead) && parent.name == :Math
            Type::F64
          end
        when Ast::MethodCall
          name = node.name
          recv = node.receiver_node
          args = node.arg_nodes || []
          # Free call to a typed-return method
          if recv.nil? && (ret_ty = @gctx.typed_method_returns[name])
            return ret_ty
          end
          # Self-call inside class body with known raw return (e.g. attr_accessor)
          if recv.nil? && @cctx.name &&
             (ret_ty = @gctx.instance_method_raw_returns[[@cctx.name, name]])
            return ret_ty
          end
          # Math.sqrt, Math.sin, etc. always return Float64
          if recv.is_a?(Ast::ConstantRead) && recv.name == :Math
            return Type::F64
          end
          # Instance method call on a class-typed local with known raw return type
          if recv.is_a?(Ast::LocalVariableRead)
            recv_class = @mctx.class_locals[recv.name]
            if recv_class && (ret_ty = @gctx.instance_method_raw_returns[[recv_class, name]])
              return ret_ty
            end
          end
          # Typed array element read: a[k] where a is a typed or native array local
          if name == :[] && args.size == 1 && recv.is_a?(Ast::LocalVariableRead)
            arr_name = recv.name
            nat_ty = native_array_elem_type(arr_name)
            return nat_ty if nat_ty
            # Boxed RubyArray with known elem type from TI
            elem_ty = @mctx.local_array_elems[arr_name]
            return elem_ty if elem_ty
          end
          # succ/pred on typed integer → same type
          if (name == :succ || name == :pred) && args.empty? && node_raw_type(recv)&.i64?
            return Type::I64
          end
          # Explicit coercion methods → known return type
          return Type::F64 if %i[to_f to_f64].include?(name) && args.empty? && recv
          return Type::I64 if %i[to_i to_i64].include?(name) && args.empty? && recv
          # Arithmetic op: BOTH operands must be raw-typed
          return nil unless ARITH_OPS_UNBOX.include?(name) && args.size == 1
          rt = node_raw_type(recv)
          at = node_raw_type(args[0])
          return nil unless rt && at
          (rt.f64? || at.f64?) ? Type::F64 : Type::I64
        when Ast::IndexOperatorWrite
          # sr[i] += 1 on a native Array(Int64) returns Int64
          recv = node.receiver_node
          if recv.is_a?(Ast::LocalVariableRead)
            arr_name = recv.name
            nat_ty = native_array_elem_type(arr_name)
            return nat_ty if nat_ty
          end
          nil
        else nil
        end
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
      # Only call when node_raw_type(node) is non-nil.
      # Returns String — callers write the result.
      def raw(node)
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
        when Ast::MethodCall then raw_call(node)
        else capture { emit(node) }
        end
      end

      # Backward compat — imperative callers that expect write side effect.
      def emit_raw(node) = write raw(node)

      # Emit a MethodCall node as bare Crystal numeric in raw context.
      # Return Crystal source for a MethodCall in raw context.
      def raw_call(node)
        name = node.name
        recv = node.receiver_node
        args = node.arg_nodes || []
        raw_coercion(name, recv) ||
          raw_succ_pred(name, recv) ||
          raw_array_read(name, recv, args, node) ||
          raw_self_accessor(name, recv) ||
          raw_typed_free_call(name, recv, args, node) ||
          raw_class_instance_call(name, recv) ||
          raw_math_call(name, recv, args) ||
          raw_arithmetic(name, recv, args) ||
          raw_call_fallback(node, name, recv)
      end

      def raw_coercion(name, recv)
        return unless recv
        if %i[to_f to_f64].include?(name) then node_raw_type(recv)&.f64? ? raw(recv) : "#{raw(recv)}.to_f64"
        elsif %i[to_i to_i64].include?(name) then node_raw_type(recv)&.i64? ? raw(recv) : "#{raw(recv)}.to_i64"
        end
      end

      def raw_succ_pred(name, recv)
        return unless (name == :succ || name == :pred) && node_raw_type(recv)&.i64?
        "(#{raw(recv)} #{name == :succ ? '+ 1_i64' : '- 1_i64'})"
      end

      def raw_array_read(name, recv, args, node)
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

      def raw_self_accessor(name, recv)
        return unless recv.nil? && @cctx.name &&
          @gctx.instance_method_raw_returns[[@cctx.name, name]] && accessor_method_name?(name)
        "#{crystal_method_name(name)}_raw"
      end

      def raw_typed_free_call(name, recv, args, node)
        return unless recv.nil? && @gctx.typed_params[name]
        s = "#{crystal_method_name(name)}(#{args.map { |a| raw(a) }.join(', ')})"
        unless @gctx.typed_method_returns[name]
          ret = node_raw_type(node)
          s += (ret&.f64? ? ".to_f64" : ".to_i64") if ret
        end
        s
      end

      def raw_class_instance_call(name, recv)
        return unless recv.is_a?(Ast::LocalVariableRead)
        recv_class = @mctx.class_locals[recv.name] or return
        @gctx.instance_method_raw_returns[[recv_class, name]] or return
        "#{raw(recv)}.as(Ruby_#{crystal_constant(recv_class)}).#{crystal_method_name(name)}_raw"
      end

      def raw_math_call(name, recv, args)
        return unless recv.is_a?(Ast::ConstantRead) && recv.name == :Math &&
          args.size >= 1 && args.all? { |a| node_raw_type(a) }
        "Math.#{name}(#{args.map { |a| raw(a) }.join(', ')})"
      end

      def raw_arithmetic(name, recv, args)
        return unless (ARITH_OPS_UNBOX | CrystalEmitter::COMPARE_OPS).include?(name) && args.size == 1 && recv
        ty = (node_raw_type(recv)&.f64? || node_raw_type(args[0])&.f64?) ? Type::F64 : Type::I64
        op = (name == :/ && ty.i64?) ? "//" : name.to_s
        "(#{raw_as(recv, ty)} #{op} #{raw_as(args[0], ty)})"
      end

      def raw_call_fallback(node, name, recv)
        s = capture { emit(node) }
        ret = @gctx.typed_method_returns[name] if recv.nil?
        ret ? "#{s}#{ret.f64? ? '.to_f64' : '.to_i64'}" : s
      end

      # Return Crystal source for node coerced to the given raw type.
      def raw_as(node, ty)
        nt = node_raw_type(node)
        return raw(node) if nt == ty
        return "#{raw(node)}.to_f64" if nt&.i64? && ty.f64?
        # Recurse into arithmetic with at least one typed operand
        if node.is_a?(Ast::MethodCall)
          name = node.name
          recv = node.receiver_node
          args = node.arg_nodes || []
          if (ARITH_OPS_UNBOX | CrystalEmitter::COMPARE_OPS).include?(name) && args.size == 1 && recv
            rt = node_raw_type(recv)
            at = node_raw_type(args[0])
            if rt || at
              op = (name == :/ && ty.i64?) ? "//" : name.to_s
              return "(#{raw_as(recv, ty)} #{op} #{raw_as(args[0], ty)})"
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
      # emit_raw_expr — complete raw expression emitter for typed method bodies.
      # Never boxes. Every expression emits as a bare Crystal value.
      # Falls back to emit(node) ONLY for node types that are inherently
      # RubyObject-valued (string literals, hash literals, etc.)
      # -----------------------------------------------------------------------

      def emit_raw_expr(node)
        case node
        when Ast::IntegerLiteral
          write "#{node.value.raw}_i64"
        when Ast::FloatLiteral
          raw = node.value
          val = raw.respond_to?(:raw) ? raw.raw : raw
          write float_bits_expr(val)
        when Ast::NilLiteral
          write "RUBY_NIL"
        when Ast::TrueLiteral
          write "true"
        when Ast::FalseLiteral
          write "false"
        when Ast::LocalVariableRead
          # Bare Crystal local — no boxing. Typed locals are already the right type.
          write crystal_local(node.name)
        when Ast::InstanceVariableRead
          iv = node.name
          case (iv_ty = @cctx&.ivars&.dig(iv))
          when Type::I64, Type::F64, Type::ARRAY_I64, Type::ARRAY_F64
            write iv.to_s  # bare ivar
          else
            write iv.to_s  # still bare — caller decides whether to box
          end
        when Ast::LocalVariableWrite
          name = node.name
          # Delegate array construction to specialised handlers
          return if try_nested_array_write(node, name)
          return if try_range_to_a_write(node, name)
          return if try_native_dup_write(node, name)
          return if try_typed_array_write(node, name)
          return if try_boxed_array_promote(node, name)
          # Skip try_scalar_write and try_class_cast_write in raw context —
          # they use emit_as/emit which box. Raw context handles these natively.
          write crystal_local(name), " = "
          emit_raw_expr(node.value_node)
        when Ast::Sequence
          node.nodes.each_with_index do |n, i|
            if i < node.nodes.size - 1
              emit_indent; emit_raw_expr(n); emit_newline
            else
              emit_raw_expr(n)
            end
          end
        when Ast::MethodCall
          result = raw_expr_call(node)
          if result.is_a?(String) then write result
          elsif !result then emit(node)
          end
        when Ast::AttributeWrite
          # @list[i] = val on typed array ivars
          recv = node.receiver_node
          if node.name == :[]= && recv.is_a?(Ast::InstanceVariableRead)
            iv_ty = @cctx&.ivars&.dig(recv.name)
            if iv_ty == Type::ARRAY_F64 || iv_ty == Type::ARRAY_I64
              args = node.arg_nodes
              write recv.name.to_s, "["
              emit_raw_expr(args[0])
              write "] = "
              emit_raw_expr(args[1])
              return
            end
          end
          emit(node)  # fall back for non-array attribute writes
        when Ast::If
          then_n = node.then_node
          else_n = node.else_node
          # Check if branches produce mixed numeric types — coerce to Float64
          then_ty = node_raw_type(then_n)
          else_ty = else_n ? node_raw_type(else_n) : nil
          needs_float = (then_ty&.f64? && else_ty&.i64?) || (then_ty&.i64? && else_ty&.f64?)
          write "if "
          emit_raw_truthy(node.pred_node)
          emit_newline
          indented { emit_indent; needs_float && then_ty&.i64? ? (emit_raw_expr(then_n); write ".to_f64") : emit_raw_expr(then_n) }
          if else_n
            emit_newline; emit_indent; write "else"; emit_newline
            indented { emit_indent; needs_float && else_ty&.i64? ? (emit_raw_expr(else_n); write ".to_f64") : emit_raw_expr(else_n) }
          end
          emit_newline; emit_indent; write "end"
        when Ast::And
          write "("; emit_raw_expr(node.left_node)
          write " && "; emit_raw_expr(node.right_node); write ")"
        when Ast::Or
          write "("; emit_raw_expr(node.left_node)
          write " || "; emit_raw_expr(node.right_node); write ")"
        when Ast::Return
          write "return "
          emit_raw_expr(node.value_node) if node.value_node
        when Ast::ConstantRead
          name = node.name
          write "Ruby_#{crystal_constant(name)}"
        when Ast::ConstantPath
          parent = node.parent_node
          if parent.is_a?(Ast::ConstantRead) && parent.name == :Math
            write "Math::#{node.name}"
          else
            emit(node)
          end
        else
          emit(node)  # unhandled node type — fall back to boxed emit
        end
      end

      # Emit a truthy check in raw context — use native Crystal booleans
      def raw_truthy(node)
        if node.is_a?(Ast::MethodCall) &&
           (ARITH_OPS_UNBOX | CrystalEmitter::COMPARE_OPS).include?(node.name) &&
           node.receiver_node && (node.arg_nodes || []).size == 1
          "(#{capture { emit_raw_expr(node.receiver_node) }} #{node.name} #{capture { emit_raw_expr(node.arg_nodes[0]) }})"
        elsif node.is_a?(Ast::And)
          "(#{raw_truthy(node.left_node)} && #{raw_truthy(node.right_node)})"
        elsif node.is_a?(Ast::Or)
          "(#{raw_truthy(node.left_node)} || #{raw_truthy(node.right_node)})"
        else
          capture { emit_raw_expr(node) }
        end
      end

      def emit_raw_truthy(node) = write raw_truthy(node)

      # Try to emit a method call in raw mode. Returns true if handled.
      # Try to produce Crystal source for a method call in raw_expr context.
      # Returns String or nil (unhandled — caller falls back to emit).
      def raw_expr_call(node)
        name = node.name
        recv = node.receiver_node
        args = node.arg_nodes || []
        raw_expr_math(name, recv, args) ||
          raw_expr_arith(name, recv, args) ||
          raw_expr_coerce(name, recv) ||
          raw_expr_unary(name, recv) ||
          raw_expr_numeric_method(name, recv) ||
          raw_expr_module_call(name, recv, args, node) ||
          raw_expr_min_max(name, recv, args) ||
          raw_expr_free_call(name, recv, args, node) ||
          raw_expr_instance_call(name, recv, args, node)
      end

      def raw_expr_math(name, recv, args)
        return unless recv.is_a?(Ast::ConstantRead) && recv.name == :Math
        "Math.#{name}(#{expr_args(args)})"
      end

      def raw_expr_arith(name, recv, args)
        return unless (ARITH_OPS_UNBOX | CrystalEmitter::COMPARE_OPS).include?(name) && args.size == 1 && recv
        op = (name == :/ && node_raw_type(recv)&.i64? && node_raw_type(args[0])&.i64?) ? "//" : name.to_s
        "(#{capture { emit_raw_expr(recv) }} #{op} #{capture { emit_raw_expr(args[0]) }})"
      end

      def raw_expr_coerce(name, recv)
        return unless recv
        s = capture { emit_raw_expr(recv) }
        if %i[to_f to_f64].include?(name) then "#{s}.to_f64"
        elsif %i[to_i to_i64].include?(name) then "#{s}.to_i64"
        end
      end

      def raw_expr_unary(name, recv)
        return unless recv
        s = capture { emit_raw_expr(recv) }
        if name == :-@ then "(-#{s})"
        elsif name == :+@ then s
        end
      end

      def raw_expr_numeric_method(name, recv)
        return unless %i[abs floor ceil round].include?(name) && recv
        s = "#{capture { emit_raw_expr(recv) }}.#{name}"
        s += ".to_i64" if %i[floor ceil round].include?(name) && node_raw_type(recv)&.f64?
        s
      end

      def raw_expr_module_call(name, recv, args, node)
        return unless recv.is_a?(Ast::ConstantRead)
        cr_type = CrystalEmitter::RUBY_TO_CRYSTAL_TYPE[recv.name] || "Ruby_#{crystal_constant(recv.name)}"
        arg_str = (name == :new && CrystalEmitter::RUBY_TO_CRYSTAL_TYPE.key?(recv.name)) ?
          args.map { |a| capture { emit(a) } }.join(", ") : expr_args(args)
        write "#{cr_type}.#{crystal_method_name(name)}(#{arg_str})"
        emit_raw_block(node)
        true  # special: writes + block side effect, returns truthy
      end

      def raw_expr_min_max(name, recv, args)
        return unless (name == :min || name == :max) && args.size == 2 && (recv.nil? || recv.is_a?(Ast::SelfLiteral))
        "Math.#{name}(#{expr_args(args)})"
      end

      def raw_expr_free_call(name, recv, args, node)
        return unless recv.nil? || recv.is_a?(Ast::SelfLiteral)
        mkey = @cctx&.name ? [@cctx.name, name] : name
        raw_params = @gctx.class_params&.dig(mkey) || @gctx.typed_params&.dig(name)
        has_typed = raw_params&.any? { |t| t&.raw? }
        prefix = recv.is_a?(Ast::SelfLiteral) ? "self." : ""
        arg_str = if has_typed
          args.each_with_index.map { |a, i|
            s = capture { emit_raw_expr(a) }
            pty = (raw_params && i < raw_params.size) ? raw_params[i] : nil
            s += ".to_i64" if pty&.i64?
            s += ".to_f64" if pty&.f64?
            s
          }.join(", ")
        else
          args.map { |a| capture { emit(a) } }.join(", ")
        end
        write "#{prefix}#{crystal_method_name(name)}(#{arg_str})"
        emit_raw_block(node)
        unless has_typed
          ret = node_raw_type(node)
          write(ret&.f64? ? ".to_f64" : ".to_i64") if ret
        end
        true  # writes + block side effect
      end

      def raw_expr_instance_call(name, recv, args, node)
        return unless recv.is_a?(Ast::LocalVariableRead)
        recv_name = recv.name
        return unless @mctx.typed_locals[recv_name] || @mctx.class_locals&.dig(recv_name) || @mctx.native_array_locals&.dig(recv_name)
        s = "#{crystal_local(recv_name)}.#{crystal_method_name(name)}(#{expr_args(args)})"
        recv_cls = @mctx.class_locals&.dig(recv_name)
        recv_cls = recv_cls.is_a?(Array) ? recv_cls[0] : recv_cls
        if recv_cls && (ret = @gctx.instance_method_raw_returns&.dig([recv_cls, name]))
          s += ret.f64? ? ".to_f64" : ".to_i64"
        end
        write s
        emit_raw_block(node)
        true  # writes + block side effect
      end

      # Comma-separated args emitted through emit_raw_expr.
      def expr_args(args) = args.map { |a| capture { emit_raw_expr(a) } }.join(", ")

      # Emit a block in raw context (e.g., n.times { |i| ... })
      def emit_raw_block(node)
        blk = node.block_node
        return unless blk.is_a?(Ast::Block)
        params = blk.required_params || []
        write " { "
        unless params.empty?
          write "|"
          write params.map { |p| crystal_local(p) }.join(", ")
          write "| "
        end
        emit_raw_expr(blk.body) if blk.body
        write " }"
      end

      end
    end
  end
end
