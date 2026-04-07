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
      def emit_raw_expr_args(args) = write args.map { |a| capture { emit_raw_expr(a) } }.join(", ")

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
          if (name == :succ || name == :pred) && args.empty? && Type.i64?(node_raw_type(recv))
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
          (Type.f64?(rt) || Type.f64?(at)) ? Type::F64 : Type::I64
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
              nt == ty || (Type.f64?(ty) && Type.i64?(nt))
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
        if %i[to_f to_f64].include?(name) then Type.f64?(node_raw_type(recv)) ? raw(recv) : "#{raw(recv)}.to_f64"
        elsif %i[to_i to_i64].include?(name) then Type.i64?(node_raw_type(recv)) ? raw(recv) : "#{raw(recv)}.to_i64"
        end
      end

      def raw_succ_pred(name, recv)
        return unless (name == :succ || name == :pred) && Type.i64?(node_raw_type(recv))
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
          s += (Type.f64?(ret) ? ".to_f64" : ".to_i64") if ret
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
        ty = (Type.f64?(node_raw_type(recv)) || Type.f64?(node_raw_type(args[0]))) ? Type::F64 : Type::I64
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
        ty_f64 = Type.f64?(ty)
        ty_i64 = Type.i64?(ty)
        nt = node_raw_type(node)
        return raw(node) if nt == ty || (Type.f64?(nt) && ty_f64) || (Type.i64?(nt) && ty_i64)
        return "#{raw(node)}.to_f64" if Type.i64?(nt) && ty_f64
        # Recurse into arithmetic with at least one typed operand
        if node.is_a?(Ast::MethodCall)
          name = node.name
          recv = node.receiver_node
          args = node.arg_nodes || []
          if (ARITH_OPS_UNBOX | CrystalEmitter::COMPARE_OPS).include?(name) && args.size == 1 && recv
            rt = node_raw_type(recv)
            at = node_raw_type(args[0])
            if rt || at
              op = (name == :/ && ty_i64) ? "//" : name.to_s
              return "(#{raw_as(recv, ty)} #{op} #{raw_as(args[0], ty)})"
            end
          end
        end
        # Fallback: emit boxed and coerce.
        s = capture { emit(node) }
        s = "(#{s})" if contains_assignment?(node)
        "#{s}#{ty_f64 ? '.to_f64' : '.to_i64'}"
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

      def raw_lines(node)
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
        when Ast::And then ["(#{raw_lines(node.left_node).join} && #{raw_lines(node.right_node).join})"]
        when Ast::Or  then ["(#{raw_lines(node.left_node).join} || #{raw_lines(node.right_node).join})"]
        when Ast::Sequence then node.nodes.flat_map { |n| raw_lines(n) }
        when Ast::If then raw_lines_if(node)
        when Ast::Return then node.value_node ? ["return #{raw_lines(node.value_node).join}"] : ["return"]
        when Ast::LocalVariableWrite then raw_lines_local_write(node)
        when Ast::AttributeWrite then raw_lines_attr_write(node)
        when Ast::MethodCall then raw_lines_method_call(node)
        else [capture { emit(node) }]
        end
      end

      def raw_lines_if(node)
        then_ty = node_raw_type(node.then_node)
        else_ty = node.else_node ? node_raw_type(node.else_node) : nil
        needs_float = (Type.f64?(then_ty) && Type.i64?(else_ty)) || (Type.i64?(then_ty) && Type.f64?(else_ty))
        then_lines = raw_lines(node.then_node)
        then_lines[-1] += ".to_f64" if needs_float && Type.i64?(then_ty) && then_lines.any?
        lines = ["if #{raw_truthy(node.pred_node)}", *indent(then_lines)]
        if node.else_node
          else_lines = raw_lines(node.else_node)
          else_lines[-1] += ".to_f64" if needs_float && Type.i64?(else_ty) && else_lines.any?
          lines.push("else", *indent(else_lines))
        end
        lines << "end"
      end

      def raw_lines_local_write(node)
        name = node.name
        # Specialised array constructors still write imperatively.
        handled = capture {
          try_nested_array_write(node, name) || try_range_to_a_write(node, name) ||
            try_native_dup_write(node, name) || try_typed_array_write(node, name) ||
            try_boxed_array_promote(node, name)
        }
        return [handled] unless handled.empty?
        val = raw_lines(node.value_node)
        if val.size == 1
          ["#{crystal_local(name)} = #{val[0]}"]
        else
          ["#{crystal_local(name)} = begin", *indent(val), "end"]
        end
      end

      def raw_lines_attr_write(node)
        recv = node.receiver_node
        if node.name == :[]= && recv.is_a?(Ast::InstanceVariableRead)
          iv_ty = @cctx&.ivars&.dig(recv.name)
          if Type.array_raw?(iv_ty)
            args = node.arg_nodes
            return ["#{recv.name}[#{raw_lines(args[0]).join}] = #{raw_lines(args[1]).join}"]
          end
        end
        [capture { emit(node) }]
      end

      def raw_lines_method_call(node)
        result = nil
        captured = capture { result = raw_expr_call(node) }
        if result.is_a?(String)
          [result]
        elsif result
          [captured]
        else
          [capture { emit(node) }]
        end
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

      # Return a Crystal boolean expression string for raw-context truthiness.
      def raw_truthy(node)
        if node.is_a?(Ast::MethodCall) &&
           (ARITH_OPS_UNBOX | CrystalEmitter::COMPARE_OPS).include?(node.name) &&
           node.receiver_node && (node.arg_nodes || []).size == 1
          "(#{raw_lines(node.receiver_node).join} #{node.name} #{raw_lines(node.arg_nodes[0]).join})"
        elsif node.is_a?(Ast::And)
          "(#{raw_truthy(node.left_node)} && #{raw_truthy(node.right_node)})"
        elsif node.is_a?(Ast::Or)
          "(#{raw_truthy(node.left_node)} || #{raw_truthy(node.right_node)})"
        else
          raw_lines(node).join("\n")
        end
      end

      def emit_raw_truthy(node) = write raw_truthy(node)

      # Try to produce Crystal source for a method call in raw_expr context.
      # Returns String (pure result), true (already written + side effect), or nil (unhandled).
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
        op = (name == :/ && Type.i64?(node_raw_type(recv)) && Type.i64?(node_raw_type(args[0]))) ? "//" : name.to_s
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
        s += ".to_i64" if %i[floor ceil round].include?(name) && Type.f64?(node_raw_type(recv))
        s
      end

      def raw_expr_module_call(name, recv, args, node)
        return unless recv.is_a?(Ast::ConstantRead)
        cr_type = CrystalEmitter::RUBY_TO_CRYSTAL_TYPE[recv.name] || "Ruby_#{crystal_constant(recv.name)}"
        arg_str = (name == :new && CrystalEmitter::RUBY_TO_CRYSTAL_TYPE.key?(recv.name)) ?
          args.map { |a| capture { emit(a) } }.join(", ") : expr_args(args)
        write "#{cr_type}.#{crystal_method_name(name)}(#{arg_str})"
        emit_raw_block(node)
        true
      end

      def raw_expr_min_max(name, recv, args)
        return unless (name == :min || name == :max) && args.size == 2 && (recv.nil? || recv.is_a?(Ast::SelfLiteral))
        "Math.#{name}(#{expr_args(args)})"
      end

      def raw_expr_free_call(name, recv, args, node)
        return unless recv.nil? || recv.is_a?(Ast::SelfLiteral)
        mkey = @cctx&.name ? [@cctx.name, name] : name
        raw_params = @gctx.class_params&.dig(mkey) || @gctx.typed_params&.dig(name)
        has_typed = raw_params&.any? { |t| Type.raw?(t) }
        prefix = recv.is_a?(Ast::SelfLiteral) ? "self." : ""
        arg_str = if has_typed
          args.each_with_index.map { |a, i|
            s = capture { emit_raw_expr(a) }
            pty = (raw_params && i < raw_params.size) ? raw_params[i] : nil
            s += ".to_i64" if Type.i64?(pty)
            s += ".to_f64" if Type.f64?(pty)
            s
          }.join(", ")
        else
          args.map { |a| capture { emit(a) } }.join(", ")
        end
        write "#{prefix}#{crystal_method_name(name)}(#{arg_str})"
        emit_raw_block(node)
        unless has_typed
          ret = node_raw_type(node)
          write(Type.f64?(ret) ? ".to_f64" : ".to_i64") if ret
        end
        true
      end

      def raw_expr_instance_call(name, recv, args, node)
        return unless recv.is_a?(Ast::LocalVariableRead)
        recv_name = recv.name
        return unless @mctx.typed_locals[recv_name] || @mctx.class_locals&.dig(recv_name) || @mctx.native_array_locals&.dig(recv_name)
        s = "#{crystal_local(recv_name)}.#{crystal_method_name(name)}(#{expr_args(args)})"
        recv_cls = @mctx.class_locals&.dig(recv_name)
        recv_cls = recv_cls.is_a?(Array) ? recv_cls[0] : recv_cls
        if recv_cls && (ret = @gctx.instance_method_raw_returns&.dig([recv_cls, name]))
          s += Type.f64?(ret) ? ".to_f64" : ".to_i64"
        end
        write s
        emit_raw_block(node)
        true
      end

      # Comma-separated args emitted through emit_raw_expr.
      def expr_args(args) = args.map { |a| capture { emit_raw_expr(a) } }.join(", ")

      # Backward compat — imperative dispatcher returning bool.
      def emit_raw_method_call(node)
        result = raw_expr_call(node)
        if result.is_a?(String)
          write result
          true
        else
          result
        end
      end

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
