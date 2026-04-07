# Array type analysis and escape analysis for Codegen.
#
# Provides:
# - native_array_elem_type: lookup for Array(T) locals
# - detect_nested_array_locals: find Array.new(n){Array.new(m,fill)} nested native-typed patterns
# - local_escapes?: conservative escape analysis for array promotion safety
# - seed_typed_array_locals / infer_typed_array_locals: Array(T) inference
# - array_new_call?: pattern matching helper
# - scan_array_uses: track how arrays are accessed
#
# Dependencies: calls node_raw_type, collect_local_assignments (RawEmission).

module Frozone
  module Compiler
    module CodegenSupport
      module ArrayAnalysis
      def native_array_elem_type(arr_name) = @mctx.typed_array_locals[arr_name] || @mctx.native_array_locals[arr_name]

      # Detect locals assigned from Array.new(count_i64) { Array.new(count2_i64, fill) }
      # where fill is a typed scalar. Returns {name => :i64 | :f64}.
      def detect_nested_array_locals(body, exclude_names)
        return {} unless body
        assignments = Hash.new { |h, k| h[k] = [] }
        collect_local_assignments(body, assignments)
        result = {}
        assignments.each do |name, rhs_nodes|
          next if exclude_names.include?(name)
          next unless rhs_nodes.size == 1
          rhs = rhs_nodes.first
          # Outer: Array.new(count_i64) { inner_body } — block form with one arg
          next unless rhs.is_a?(Ast::MethodCall) && rhs.name == :new
          outer_recv = rhs.receiver_node
          next unless outer_recv.is_a?(Ast::ConstantRead) && outer_recv.name == :Array
          blk = rhs.block_node
          next unless blk.is_a?(Ast::Block)
          outer_args = rhs.arg_nodes || []
          next unless outer_args.size == 1 && Type.i64?(node_raw_type(outer_args[0]))
          # Inner block body must be Array.new(count2_i64, fill_scalar) — no block
          inner = blk.body
          inner = inner.nodes.first if inner.is_a?(Ast::Sequence) && inner.nodes.size == 1
          next unless array_new_call?(inner)
          inner_args = inner.arg_nodes || []
          fill_ty = node_raw_type(inner_args[1])
          next unless fill_ty
          # Don't promote if the variable escapes — UNLESS it only escapes
          # via the method's final array literal return (Crystal tuple preserves type).
          next if local_escapes?(body, name) && !escapes_only_via_return_literal?(body, name)
          result[name] = fill_ty
        end
        result
      end

      # Does the local escape only via the final array literal (multi-return)?
      # Safe to promote because Crystal tuple return preserves the type.
      def escapes_only_via_return_literal?(body, name)
        last = body.is_a?(Ast::Sequence) ? body.nodes.last : body
        return false unless last.is_a?(Ast::ArrayLiteral)
        elems = last.element_nodes || []
        elems.any? { |e| e.is_a?(Ast::LocalVariableRead) && e.name == name }
      end

      # Check if a local variable is used beyond simple indexing (read/write).
      def local_escapes?(node, name)
        return false unless node
        case node
        when Ast::LocalVariableRead
          node.name == name
        when Ast::MethodCall
          call_name = node.name
          recv = node.receiver_node
          args = node.arg_nodes || []
          if (call_name == :[] || call_name == :[]=) && recv.is_a?(Ast::LocalVariableRead) && recv.name == name
            return args.any? { |a| local_escapes?(a, name) } ||
                   (node.block_node ? local_escapes?(node.block_node, name) : false)
          end
          (recv ? local_escapes?(recv, name) : false) ||
            args.any? { |a| local_escapes?(a, name) } ||
            (node.block_node ? local_escapes?(node.block_node, name) : false)
        when Ast::Sequence then node.nodes.any? { |n| local_escapes?(n, name) }
        when Ast::If
          [node.condition, node.then_node, node.else_node].any? { |n| local_escapes?(n, name) }
        when Ast::While
          local_escapes?(node.condition_node, name) || local_escapes?(node.body_node, name)
        when Ast::Block then local_escapes?(node.body, name)
        when Ast::LocalVariableWrite
          node.name != name && local_escapes?(node.value_node, name)
        when Ast::ArrayLiteral then (node.element_nodes || []).any? { |e| local_escapes?(e, name) }
        when Ast::Until
          local_escapes?(node.condition_node, name) || local_escapes?(node.body_node, name)
        when Ast::Return
          local_escapes?(node.value_node, name)
        when Ast::MultipleAssignment
          local_escapes?(node.value_node, name)
        when Ast::HashLiteral
          (node.kv_nodes || []).any? { |k, v| local_escapes?(k, name) || local_escapes?(v, name) }
        when Ast::Case
          local_escapes?(node.subject_node, name) ||
            (node.whens || []).any? { |w| w.condition_nodes.any? { |c| local_escapes?(c, name) } || local_escapes?(w.body_node, name) } ||
            local_escapes?(node.else_node, name)
        when Ast::IndexOperatorWrite
          recv = node.receiver_node
          idx_args = node.index_arg_nodes || []
          val = node.value_node
          if recv.is_a?(Ast::LocalVariableRead) && recv.name == name
            idx_args.any? { |a| local_escapes?(a, name) } || local_escapes?(val, name)
          else
            local_escapes?(recv, name) || idx_args.any? { |a| local_escapes?(a, name) } || local_escapes?(val, name)
          end
        when Ast::InstanceVariableWrite
          local_escapes?(node.value_node, name)
        when Ast::Rescue
          local_escapes?(node.body, name) ||
            local_escapes?(node.else_node, name) ||
            local_escapes?(node.ensure_node, name)
        else false
        end
      end

      # -----------------------------------------------------------------------

      # Phase-1 seed: find Array.new(count, fill) locals where fill is typed.
      # No escape/write validation yet — used so node_raw_type is accurate when
      # infer_local_types runs in phase 2.
      def seed_typed_array_locals(body, exclude_names)
        return {} unless body
        assignments = Hash.new { |h, k| h[k] = [] }
        collect_local_assignments(body, assignments)
        result = {}
        assignments.each do |name, rhs_nodes|
          next if exclude_names.include?(name)
          next unless rhs_nodes.size == 1
          rhs = rhs_nodes.first
          next unless array_new_call?(rhs)
          args = rhs.arg_nodes || []
          next unless args.size == 2
          fill_ty = node_raw_type(args[1])
          next unless fill_ty
          result[name] = fill_ty
        end
        result
      end

      # Infer which local variables are typed arrays that can be emitted as
      # Crystal Array(Int64) / Array(Float64) instead of RubyArray.
      #
      # A local qualifies when:
      #   1. It has exactly one assignment: Array.new(count, fill) with typed fill.
      #   2. It is never passed as an argument to any method (no escape).
      #   3. It is never assigned from or to another variable (no aliasing).
      #   4. It is never returned or stored in an ivar/constant.
      #   5. All []= writes have values consistent with the element type.
      def infer_typed_array_locals(body, exclude_names)
        return {} unless body

        assignments = Hash.new { |h, k| h[k] = [] }
        collect_local_assignments(body, assignments)

        candidates = {}
        assignments.each do |name, rhs_nodes|
          next if exclude_names.include?(name)
          next unless rhs_nodes.size == 1
          rhs = rhs_nodes.first
          next unless array_new_call?(rhs)
          args = rhs.arg_nodes || []
          next unless args.size == 2
          fill_ty = node_raw_type(args[1])
          next unless fill_ty
          candidates[name] = fill_ty
        end
        return {} if candidates.empty?

        escaped = Set.new
        scan_array_uses(body, candidates, escaped)
        candidates.reject { |name, _| escaped.include?(name) }
      end

      # Returns true if node is Array.new(count, fill) with exactly 2 args, no block.
      def array_new_call?(node)
        return false unless node.is_a?(Ast::MethodCall)
        return false unless node.name == :new
        recv = node.receiver_node
        return false unless recv.is_a?(Ast::ConstantRead) && recv.name == :Array
        return false unless (node.arg_nodes || []).size == 2
        node.block_node.nil?
      end

      # Walk body detecting uses of candidate array locals that would disqualify them.
      # Marks names in `escaped` for any unsafe use.
      def scan_array_uses(node, candidates, escaped)
        return unless node
        case node
        when Ast::MethodCall
          recv = node.receiver_node
          args = node.arg_nodes || []
          if recv.is_a?(Ast::LocalVariableRead) && candidates.key?(recv.name)
            lv = recv.name
            if node.name == :[]
              # Read — OK; index and any block arg are checked below
            elsif node.name == :[]=
              # Write — validate value type matches element type
              val = args[1]
              val_ty = val ? node_raw_type(val) : nil
              expected = candidates[lv]
              ok = val_ty == expected || (Type.i64?(val_ty) && Type.f64?(expected))
              escaped << lv unless ok
            else
              escaped << lv  # other method on array = escape
            end
          else
            scan_array_uses(recv, candidates, escaped)
          end
          # Any arg that IS a candidate local itself = passed to method = escape
          args.each do |a|
            if a.is_a?(Ast::LocalVariableRead) && candidates.key?(a.name)
              escaped << a.name
            else
              scan_array_uses(a, candidates, escaped)
            end
          end
          blk = node.block_node
          scan_array_uses(blk&.body, candidates, escaped) if blk
        when Ast::AttributeWrite
          recv = node.receiver_node
          args = node.arg_nodes || []
          if node.name == :[]= && recv.is_a?(Ast::LocalVariableRead) &&
             candidates.key?(recv.name)
            lv = recv.name
            val = args[1]
            val_ty = val ? node_raw_type(val) : nil
            expected = candidates[lv]
            ok = val_ty == expected || (Type.i64?(val_ty) && Type.f64?(expected))
            escaped << lv unless ok
          else
            scan_array_uses(recv, candidates, escaped)
          end
          args.each do |a|
            if a.is_a?(Ast::LocalVariableRead) && candidates.key?(a.name)
              escaped << a.name
            else
              scan_array_uses(a, candidates, escaped)
            end
          end
        when Ast::LocalVariableWrite
          val = node.value_node
          # Aliasing: another variable assigned from a candidate array = escape
          if val.is_a?(Ast::LocalVariableRead) && candidates.key?(val.name)
            escaped << val.name
          else
            scan_array_uses(val, candidates, escaped)
          end
        when Ast::Sequence
          node.nodes.each { |n| scan_array_uses(n, candidates, escaped) }
        when Ast::If
          scan_array_uses(node.condition_node, candidates, escaped)
          scan_array_uses(node.then_node, candidates, escaped)
          scan_array_uses(node.else_node, candidates, escaped)
        when Ast::While, Ast::Until
          scan_array_uses(node.condition_node, candidates, escaped)
          scan_array_uses(node.body_node, candidates, escaped)
        when Ast::Return
          val = node.value_node
          if val.is_a?(Ast::LocalVariableRead) && candidates.key?(val.name)
            escaped << val.name
          else
            scan_array_uses(val, candidates, escaped)
          end
        when Ast::InstanceVariableWrite
          val = node.value_node
          if val.is_a?(Ast::LocalVariableRead) && candidates.key?(val.name)
            escaped << val.name
          else
            scan_array_uses(val, candidates, escaped)
          end
        end
      end
      end
    end
  end
end
