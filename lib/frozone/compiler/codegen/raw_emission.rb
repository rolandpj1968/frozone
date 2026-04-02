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

      # Returns :i64, :f64, or nil for the provable bare Crystal type of a node.
      def node_raw_type(node)
        return nil unless node
        case node
        when Ast::IntegerLiteral then :i64
        when Ast::FloatLiteral   then :f64
        when Ast::Sequence       then node_raw_type(node.nodes.last) if node.nodes.any?
        when Ast::LocalVariableRead
          @mctx.typed_locals[ivar(node, :name)] || @mctx.raw_block_params[ivar(node, :name)]
        when Ast::LocalVariableWrite
          # Chained assignment: sum = maxflips = 0 — type is the inner value's type
          node_raw_type(ivar(node, :value_node))
        when Ast::InstanceVariableRead
          @cctx.ivars[ivar(node, :name)]
        when Ast::ConstantRead
          @gctx.const_raw_types[ivar(node, :name)]
        when Ast::ConstantPath
          # Math::PI, Math::E → :f64
          parent = ivar(node, :parent_node)
          if parent.is_a?(Ast::ConstantRead) && ivar(parent, :name) == :Math
            :f64
          end
        when Ast::MethodCall
          name = ivar(node, :name)
          recv = ivar(node, :receiver_node)
          args = ivar(node, :arg_nodes) || []
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
          if recv.is_a?(Ast::ConstantRead) && ivar(recv, :name) == :Math
            return :f64
          end
          # Instance method call on a class-typed local with known raw return type
          if recv.is_a?(Ast::LocalVariableRead)
            recv_class = @mctx.class_locals[ivar(recv, :name)]
            if recv_class && (ret_ty = @gctx.instance_method_raw_returns[[recv_class, name]])
              return ret_ty
            end
          end
          # Typed array element read: a[k] where a is a typed or native array local
          if name == :[] && args.size == 1 && recv.is_a?(Ast::LocalVariableRead)
            arr_name = ivar(recv, :name)
            nat_ty = native_array_elem_type(arr_name)
            return nat_ty if nat_ty
            # Boxed RubyArray with known elem type from TI
            elem_ty = @mctx.local_array_elems[arr_name]
            return elem_ty if elem_ty
          end
          # succ/pred on typed integer → same type
          if (name == :succ || name == :pred) && args.empty? && node_raw_type(recv) == :i64
            return :i64
          end
          # Explicit coercion methods → known return type
          return :f64 if %i[to_f to_f64].include?(name) && args.empty? && recv
          return :i64 if %i[to_i to_i64].include?(name) && args.empty? && recv
          # Arithmetic op: BOTH operands must be raw-typed
          return nil unless ARITH_OPS_UNBOX.include?(name) && args.size == 1
          rt = node_raw_type(recv)
          at = node_raw_type(args[0])
          return nil unless rt && at
          (rt == :f64 || at == :f64) ? :f64 : :i64
        when Ast::IndexOperatorWrite
          # sr[i] += 1 on a native Array(Int64) returns Int64
          recv = ivar(node, :receiver_node)
          if recv.is_a?(Ast::LocalVariableRead)
            arr_name = ivar(recv, :name)
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
            inner = ivar(inner, :value_node) while inner.is_a?(Ast::LocalVariableWrite)
            case inner
            when Ast::IntegerLiteral then @mctx.typed_locals[name] ||= :i64
            when Ast::FloatLiteral   then @mctx.typed_locals[name]  = :f64
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
              nt == ty || (ty == :f64 && nt == :i64)
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
      # Does not descend into block bodies (block params share Ruby scope but
      # may receive heterogeneous types from the block caller).
      def collect_local_assignments(node, result)
        return unless node
        if node.is_a?(Ast::LocalVariableWrite)
          result[ivar(node, :name)] << ivar(node, :value_node)
        end
        node.children.each do |c|
          collect_local_assignments(c, result) unless c.is_a?(Ast::Block)
        end
      end

      # Emit a node as a bare Crystal numeric (Int64 or Float64).
      # Only call when node_raw_type(node) is non-nil.
      def emit_raw(node)
        case node
        when Ast::And
          # Emit as Crystal &&: both sides must produce Crystal-compatible booleans.
          # Comparisons (CrystalEmitter::COMPARE_OPS) in emit_raw produce Crystal Bool already.
          write "("
          emit_raw(ivar(node, :left_node))
          write " && "
          emit_raw(ivar(node, :right_node))
          write ")"
        when Ast::Or
          write "("
          emit_raw(ivar(node, :left_node))
          write " || "
          emit_raw(ivar(node, :right_node))
          write ")"
        when Ast::IntegerLiteral
          write "#{ivar(node, :value).raw}_i64"
        when Ast::FloatLiteral
          raw = ivar(node, :value)
          val = raw.respond_to?(:raw) ? raw.raw : raw
          write float_bits_expr(val)
        when Ast::Sequence
          # Transparent grouping — recurse raw on the semantically relevant last node.
          nodes = node.nodes
          if nodes.size == 1
            emit_raw(nodes.first)
          else
            write "("
            nodes.each_with_index do |n, i|
              write "; " if i > 0
              i == nodes.size - 1 ? emit_raw(n) : emit(n)
            end
            write ")"
          end
        when Ast::LocalVariableRead
          write crystal_local(ivar(node, :name))
        when Ast::InstanceVariableRead
          write ivar(node, :name).to_s
        when Ast::ConstantRead
          ty = @gctx.const_raw_types[ivar(node, :name)]
          emit_constant_read(node)
          # Array constants are already native — no coercion needed
          write(ty == :f64 ? ".to_f64" : ".to_i64") unless ty == :array_i64 || ty == :array_f64
        when Ast::ConstantPath
          # Math::PI → Math::PI (already Float64 in Crystal)
          parent = ivar(node, :parent_node)
          if parent.is_a?(Ast::ConstantRead) && ivar(parent, :name) == :Math
            write "Math::#{ivar(node, :name)}"
          else
            emit(node)
            write ".to_f64"
          end
        when Ast::MethodCall
          name = ivar(node, :name)
          recv = ivar(node, :receiver_node)
          args = ivar(node, :arg_nodes) || []
          # to_f / to_i coercion → emit raw coercion
          if %i[to_f to_f64].include?(name) && args.empty? && recv
            emit_raw(recv)
            write ".to_f64" unless node_raw_type(recv) == :f64
            return
          end
          if %i[to_i to_i64].include?(name) && args.empty? && recv
            emit_raw(recv)
            write ".to_i64" unless node_raw_type(recv) == :i64
            return
          end
          # succ/pred on raw Int64 → emit as (val +/- 1)
          if (name == :succ || name == :pred) && args.empty? && node_raw_type(recv) == :i64
            write "("
            emit_raw(recv)
            write(name == :succ ? " + 1_i64)" : " - 1_i64)")
            return
          end
          if name == :[] && args.size == 1 && recv.is_a?(Ast::LocalVariableRead)
            arr_name = ivar(recv, :name)
            if (nat_ty = native_array_elem_type(arr_name))
              # Unboxed Array(T) local (typed or nested parent): a[k] → bare Int64/Float64
              write crystal_local(arr_name)
              write "["
              emit_coerce_i64(args[0])
              write "]"
            elsif (elem_ty = @mctx.local_array_elems[arr_name])
              # Boxed RubyArray with known elem type: static cast array + static unbox element
              write crystal_local(arr_name)
              write "["
              emit_coerce_i64(args[0])
              write "]"
              write elem_ty == :f64 ? ".as(RubyFloat).to_f64" : ".as(RubyInteger).to_i64"
            else
              emit(node)
            end
          elsif recv.nil? && @cctx.name &&
                @gctx.instance_method_raw_returns[[@cctx.name, name]] &&
                accessor_method_name?(name)
            # Self-call inside class with raw ACCESSOR: use _raw directly
            write "#{crystal_method_name(name)}_raw"
          elsif recv.nil? && @gctx.typed_params[name]
            # Free call to typed-param method: pass raw args
            write crystal_method_name(name)
            write "("
            args.each_with_index do |a, i|
              write ", " if i > 0
              emit_raw(a)
            end
            write ")"
            # When a specialized overload exists (typed_method_returns set), the
            # return type is already Int64/Float64 — no coerce needed.
            # Otherwise the generic overload returns RubyObject, so coerce.
            unless @gctx.typed_method_returns[name]
              ret = node_raw_type(node)
              write(ret == :f64 ? ".to_f64" : ".to_i64") if ret
            end
          elsif recv.is_a?(Ast::LocalVariableRead) &&
                (recv_class = @mctx.class_locals[ivar(recv, :name)]) &&
                (ret_ty = @gctx.instance_method_raw_returns[[recv_class, name]])
            # Instance method call on class-typed local with raw return:
            # use _raw accessor (avoids box allocation) if available, else add .to_f64/.to_i64.
            # Always emit .as(Ruby_ClassName) so Crystal's type system is happy even when
            # the variable comes from a block parameter (typed as RubyObject).
            emit_raw(recv)
            write ".as(Ruby_#{crystal_constant(recv_class)}).#{crystal_method_name(name)}_raw"
          elsif recv.is_a?(Ast::ConstantRead) && ivar(recv, :name) == :Math &&
                args.size >= 1 && args.all? { |a| node_raw_type(a) }
            # Math.sqrt(typed_arg) etc. → Crystal Math.sqrt(raw_arg), no allocation
            write "Math.#{name}("
            args.each_with_index do |a, i|
              write ", " if i > 0
              emit_raw(a)
            end
            write ")"
          elsif (ARITH_OPS_UNBOX | CrystalEmitter::COMPARE_OPS).include?(name) && args.size == 1 && recv
            rt = node_raw_type(recv)
            at = node_raw_type(args[0])
            ty = (rt == :f64 || at == :f64) ? :f64 : :i64
            write "("
            emit_as(recv, ty)
            # Crystal uses // for integer division (Ruby's / on integers)
            op = (name == :/ && ty == :i64) ? "//" : name.to_s
            write " #{op} "
            emit_as(args[0], ty)
            write ")"
          else
            emit(node)
            # If TI says this free call returns :i64/:f64 but we emitted
            # the boxed path, coerce so callers get the raw Crystal type.
            if recv.nil? && (ret = @gctx.typed_method_returns[name])
              write(ret == :f64 ? ".to_f64" : ".to_i64")
            end
          end
        else
          emit(node)
        end
      end

      # Emit node coerced to the given raw type (:i64 or :f64).
      # Recurses into arithmetic where at least one operand is typed.
      def emit_as(node, ty)
        nt = node_raw_type(node)
        # Already the right type — emit raw
        return emit_raw(node) if nt == ty
        # Int64 → Float64 promotion
        if nt == :i64 && ty == :f64
          emit_raw(node)
          write ".to_f64"
          return
        end
        # Try to recurse into arithmetic with at least one typed operand
        if node.is_a?(Ast::MethodCall)
          name = ivar(node, :name)
          recv = ivar(node, :receiver_node)
          args = ivar(node, :arg_nodes) || []
          if (ARITH_OPS_UNBOX | CrystalEmitter::COMPARE_OPS).include?(name) && args.size == 1 && recv
            rt = node_raw_type(recv)
            at = node_raw_type(args[0])
            if rt || at
              write "("
              emit_as(recv, ty)
              op = (name == :/ && ty == :i64) ? "//" : name.to_s
              write " #{op} "
              emit_as(args[0], ty)
              write ")"
              return
            end
          end
        end
        # Fallback: emit boxed and coerce.
        # Wrap assignments in parens so (q1 = expr).to_i64 groups correctly.
        if contains_assignment?(node)
          write "("; emit(node); write ")"
        else
          emit(node)
        end
        write ty == :f64 ? ".to_f64" : ".to_i64"
      end

      # Emit node coerced to Int64: raw if already typed, else .to_i64 on boxed.
      # Wrap assignments in parens so (q1 = expr).to_i64 groups correctly.
      def emit_coerce_i64(node)
        if contains_assignment?(node)
          # Assignment nodes need parens even when raw-typed (Crystal precedence)
          write "("; emit(node); write ")"
          write ".to_i64" unless node_raw_type(node)
        elsif node_raw_type(node)
          emit_raw(node)
        else
          emit(node); write ".to_i64"
        end
      end

      # Does this node contain an assignment that needs parens when used as an
      # operand? Handles Sequence([LocalVariableWrite]) from parser grouping.
      def contains_assignment?(node)
        return true if node.is_a?(Ast::LocalVariableWrite) || node.is_a?(Ast::InstanceVariableWrite)
        return true if node.is_a?(Ast::IndexOperatorWrite) || node.is_a?(Ast::AttributeWrite)
        node.is_a?(Ast::Sequence) && node.nodes.size == 1 && contains_assignment?(node.nodes.first)
      end

      # Emit node coerced to Float64: raw if already typed, else .to_f64 on boxed.
      def emit_coerce_f64(node) = node_raw_type(node) ? emit_raw(node) : (emit(node); write ".to_f64")

      # -----------------------------------------------------------------------
      # emit_raw_expr — complete raw expression emitter for typed method bodies.
      # Never boxes. Every expression emits as a bare Crystal value.
      # Falls back to emit(node) ONLY for node types that are inherently
      # RubyObject-valued (string literals, hash literals, etc.)
      # -----------------------------------------------------------------------

      def emit_raw_expr(node)
        case node
        when Ast::IntegerLiteral
          write "#{ivar(node, :value).raw}_i64"
        when Ast::FloatLiteral
          raw = ivar(node, :value)
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
          write crystal_local(ivar(node, :name))
        when Ast::InstanceVariableRead
          iv = ivar(node, :name)
          case @cctx&.ivars&.dig(iv)
          when :i64, :f64, :array_i64, :array_f64
            write iv.to_s  # bare ivar
          else
            write iv.to_s  # still bare — caller decides whether to box
          end
        when Ast::LocalVariableWrite
          name = ivar(node, :name)
          write crystal_local(name), " = "
          emit_raw_expr(ivar(node, :value_node))
        when Ast::Sequence
          node.nodes.each_with_index do |n, i|
            if i < node.nodes.size - 1
              emit_indent; emit_raw_expr(n); emit_newline
            else
              emit_raw_expr(n)
            end
          end
        when Ast::MethodCall
          # Try raw paths first, fall back to normal emit for RubyObject methods
          if emit_raw_method_call(node)
            # handled
          else
            emit(node)
            # Coerce boxed return to raw if TI knows the type
            ret = node_raw_type(node)
            write(ret == :f64 ? ".to_f64" : ".to_i64") if ret
          end
        when Ast::AttributeWrite
          # @list[i] = val on typed array ivars
          recv = ivar(node, :receiver_node)
          if ivar(node, :name) == :[]= && recv.is_a?(Ast::InstanceVariableRead)
            iv_ty = @cctx&.ivars&.dig(ivar(recv, :name))
            if iv_ty == :array_f64 || iv_ty == :array_i64
              args = ivar(node, :arg_nodes)
              write ivar(recv, :name).to_s, "["
              emit_raw_expr(args[0])
              write "] = "
              emit_raw_expr(args[1])
              return
            end
          end
          emit(node)  # fall back for non-array attribute writes
        when Ast::If
          write "if "
          emit_raw_truthy(ivar(node, :pred_node))
          emit_newline
          indented { emit_indent; emit_raw_expr(ivar(node, :then_node)) }
          if node.instance_variable_get(:@else_node)
            emit_newline; emit_indent; write "else"; emit_newline
            indented { emit_indent; emit_raw_expr(node.instance_variable_get(:@else_node)) }
          end
          emit_newline; emit_indent; write "end"
        when Ast::And
          write "("; emit_raw_expr(ivar(node, :left_node))
          write " && "; emit_raw_expr(ivar(node, :right_node)); write ")"
        when Ast::Or
          write "("; emit_raw_expr(ivar(node, :left_node))
          write " || "; emit_raw_expr(ivar(node, :right_node)); write ")"
        when Ast::Return
          write "return "
          emit_raw_expr(ivar(node, :value_node)) if ivar(node, :value_node)
        when Ast::ConstantRead
          name = ivar(node, :name)
          write "Ruby_#{crystal_constant(name)}"
        when Ast::ConstantPath
          parent = ivar(node, :parent_node)
          if parent.is_a?(Ast::ConstantRead) && ivar(parent, :name) == :Math
            write "Math::#{ivar(node, :name)}"
          else
            emit(node)
          end
        else
          emit(node)  # unhandled node type — fall back to boxed emit
        end
      end

      # Emit a truthy check in raw context — use native Crystal booleans
      def emit_raw_truthy(node)
        if node.is_a?(Ast::MethodCall) &&
           (ARITH_OPS_UNBOX | CrystalEmitter::COMPARE_OPS).include?(node.name) &&
           node.receiver_node && (node.arg_nodes || []).size == 1
          write "("; emit_raw_expr(node.receiver_node)
          write " #{node.name} "
          emit_raw_expr(node.arg_nodes[0]); write ")"
        elsif node.is_a?(Ast::And)
          write "("; emit_raw_truthy(ivar(node, :left_node))
          write " && "; emit_raw_truthy(ivar(node, :right_node)); write ")"
        elsif node.is_a?(Ast::Or)
          write "("; emit_raw_truthy(ivar(node, :left_node))
          write " || "; emit_raw_truthy(ivar(node, :right_node)); write ")"
        else
          emit_raw_expr(node)
        end
      end

      # Try to emit a method call in raw mode. Returns true if handled.
      def emit_raw_method_call(node)
        name = node.name
        recv = node.receiver_node
        args = node.arg_nodes || []

        # Math.cos, Math.sin, etc.
        if recv.is_a?(Ast::ConstantRead) && ivar(recv, :name) == :Math
          write "Math.#{name}("
          args.each_with_index { |a, i| write ", " if i > 0; emit_raw_expr(a) }
          write ")"
          return true
        end

        # Arithmetic/comparison with raw operands
        if (ARITH_OPS_UNBOX | CrystalEmitter::COMPARE_OPS).include?(name) && args.size == 1 && recv
          # Crystal uses // for integer division (Ruby's / on integers)
          op = (name == :/ && node_raw_type(recv) == :i64 && node_raw_type(args[0]) == :i64) ? "//" : name.to_s
          write "("; emit_raw_expr(recv); write " #{op} "; emit_raw_expr(args[0]); write ")"
          return true
        end

        # .to_f / .to_f64 / .to_i / .to_i64
        if %i[to_f to_f64].include?(name) && args.empty? && recv
          emit_raw_expr(recv); write ".to_f64"
          return true
        end
        if %i[to_i to_i64].include?(name) && args.empty? && recv
          emit_raw_expr(recv); write ".to_i64"
          return true
        end

        # Unary operators: -x, +x
        if name == :-@ && args.empty? && recv
          write "(-"; emit_raw_expr(recv); write ")"
          return true
        end
        if name == :+@ && args.empty? && recv
          emit_raw_expr(recv)
          return true
        end

        # .abs, .floor, .ceil, .round on numeric
        if %i[abs floor ceil round].include?(name) && args.empty? && recv
          emit_raw_expr(recv); write ".#{name}"
          # floor/ceil/round on Float64 returns Float64 in Crystal; add .to_i64 if needed
          write ".to_i64" if %i[floor ceil round].include?(name) && node_raw_type(recv) == :f64
          return true
        end

        # Module.method(...) — class/module method call, pass raw args
        if recv.is_a?(Ast::ConstantRead)
          write "Ruby_#{crystal_constant(ivar(recv, :name))}.", crystal_method_name(name)
          write "("
          args.each_with_index { |a, i| write ", " if i > 0; emit_raw_expr(a) }
          write ")"
          emit_raw_block(node)
          return true
        end

        # min/max with two raw args → Crystal Math.min/Math.max
        if (name == :min || name == :max) && args.size == 2 && (recv.nil? || recv.is_a?(Ast::SelfLiteral))
          write "Math.#{name}("
          emit_raw_expr(args[0]); write ", "; emit_raw_expr(args[1])
          write ")"
          return true
        end

        # self.method(...) — eigenclass/free method call
        if recv.nil? || (recv.is_a?(Ast::SelfLiteral))
          # Check if callee has a typed overload with raw params
          mkey = @cctx&.name ? [@cctx.name, name] : name
          raw_params = @gctx.class_params&.dig(mkey) || @gctx.typed_params&.dig(name)
          has_typed = raw_params&.any? { |t| CrystalType.raw(t) }
          write "self." if recv.is_a?(Ast::SelfLiteral)
          write crystal_method_name(name)
          write "("
          if has_typed
            args.each_with_index { |a, i| write ", " if i > 0; emit_raw_expr(a) }
          else
            # No typed overload — box args, but coerce return if TI knows it
            args.each_with_index { |a, i| write ", " if i > 0; emit(a) }
          end
          write ")"
          # Coerce return to raw if TI knows the return type
          unless has_typed  # typed overloads already return raw
            ret = node_raw_type(node)
            write(ret == :f64 ? ".to_f64" : ".to_i64") if ret
          end
          emit_raw_block(node)
          return true
        end

        # Instance method on typed/known local — direct dispatch with raw args
        if recv.is_a?(Ast::LocalVariableRead)
          recv_name = ivar(recv, :name)
          if @mctx.typed_locals[recv_name] || @mctx.class_locals&.dig(recv_name) || @mctx.native_array_locals&.dig(recv_name)
            write crystal_local(recv_name), ".", crystal_method_name(name)
            write "("
            args.each_with_index { |a, i| write ", " if i > 0; emit_raw_expr(a) }
            write ")"
            # Coerce result to raw type if the method returns a boxed numeric
            # (e.g., ThreeDArray#[] returns RubyFloat but we need Float64)
            recv_cls = @mctx.class_locals&.dig(recv_name)
            recv_cls = recv_cls.is_a?(Array) ? recv_cls[0] : recv_cls
            if recv_cls && (ret = @gctx.instance_method_raw_returns&.dig([recv_cls, name]))
              write(ret == :f64 ? ".to_f64" : ".to_i64")
            end
            emit_raw_block(node)
            return true
          end
        end

        false  # unhandled — caller falls back to emit(node)
      end

      # Emit a block in raw context (e.g., n.times { |i| ... })
      def emit_raw_block(node)
        blk = node.block_node
        return unless blk.is_a?(Ast::Block)
        params = ivar(blk, :required_params) || []
        write " { "
        unless params.empty?
          write "|"
          params.each_with_index { |p, i| write ", " if i > 0; write crystal_local(p) }
          write "| "
        end
        emit_raw_expr(blk.body) if blk.body
        write " }"
      end

      end
    end
  end
end
