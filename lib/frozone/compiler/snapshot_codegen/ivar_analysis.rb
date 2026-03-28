# Instance variable type analysis for SnapshotCodegen.
#
# Analyses all methods of user classes to determine ivar types:
# - Scalar typing: @x always holds Int64/Float64
# - Class typing: @root is Node | nil (X | nil pattern)
# - Constructor analysis: infer ivar types from initialize + call sites
#
# Dependencies: calls node_raw_type (RawEmission),
# user_source_location? (SnapshotCodegen).

module Frozone
  module Compiler
    module SnapshotCodegenSupport
      module IvarAnalysis
      # Collect user numeric constants → raw type map.
      def collect_const_raw_types(scope)
        @const_raw_types = {}
        const_table = scope.instance_variable_get(:@constants_table) || {}
        const_locs  = scope.instance_variable_get(:@constants_locations) || {}
        const_table.each do |name, value|
          next if SnapshotCodegen::SKIP_CONSTANTS.include?(name) || value.is_a?(Vm::ModuleObject)
          next unless user_source_location?(const_locs[name])
          case value
          when Vm::FloatObject   then @const_raw_types[name] = :f64
          when Vm::IntegerObject then @const_raw_types[name] = :i64
          end
        end
      end

      # For each user-defined class: infer ivar types from constructor call sites
      # in the execute block + the initialize body.
      def collect_all_ivar_types(execute_block, scope)
        @typed_ivars = {}
        return unless execute_block

        scope.instance_variable_get(:@constants_table)&.each do |name, value|
          next unless value.is_a?(Vm::ClassObject) && !SnapshotCodegen::SKIP_CONSTANTS.include?(name)

          param_types = collect_class_new_arg_types(execute_block.body, name)
          next unless param_types&.all?

          init_method = value.instance_variable_get(:@methods_table)&.fetch(:initialize, nil)
          next unless init_method.is_a?(Vm::Method) && init_method.body

          req_params = init_method.instance_variable_get(:@required_params) || []
          next unless req_params.size == param_types.size

          old_typed     = @typed_locals
          @typed_locals = req_params.zip(param_types).to_h
          ivar_types    = {}
          collect_ivar_assignments(init_method.body, ivar_types)
          @typed_locals = old_typed

          @typed_ivars[name] = ivar_types unless ivar_types.empty?
        end
      end

      # Recursively collect user-defined classes (including nested classes)
      def collect_user_classes_recursive(scope, result)
        (scope.instance_variable_get(:@constants_table) || {}).each do |name, val|
          next if SnapshotCodegen::SKIP_CONSTANTS.include?(name)
          if val.is_a?(Vm::ClassObject)
            result[name] = val
            collect_user_classes_recursive(val, result)
          end
        end
      end

      # Scan all methods of each user class for ivar assignments, collecting
      # the set of class types assigned. Produces @class_typed_ivars entries
      # for ivars with pattern {UserClass} or {UserClass, NilClass}.
      def collect_class_typed_ivars(scope)
        @class_typed_ivars = {}
        collect_class_typed_ivars_from(scope)
      end

      def collect_class_typed_ivars_from(scope)
        scope.instance_variable_get(:@constants_table)&.each do |class_name, value|
          next unless value.is_a?(Vm::ClassObject) && !SnapshotCodegen::SKIP_CONSTANTS.include?(class_name)
          collect_class_typed_ivars_from(value)  # recurse into nested classes
          methods = value.instance_variable_get(:@methods_table) || {}
          next unless methods.any? { |_, m| m.is_a?(Vm::Method) && user_source_location?(m.source_location) }

          # Collect all ivar assignment types across ALL methods
          ivar_type_sets = Hash.new { |h, k| h[k] = Set.new }
          methods.each do |mname, method|
            next unless method.is_a?(Vm::Method) && method.body
            mkey = [class_name, mname]
            method_class_locals = @ti_class_locals[mkey] || {}
            collect_ivar_class_types(method.body, ivar_type_sets, method_class_locals)
          end

          # Resolve: {ClassName} → [:class, name], {ClassName, :nil} → [:class_or_nil, name]
          # :self_ivar means the value comes from another ivar/accessor of the same
          # class — compatible with whatever class type is already identified.
          result = {}
          ivar_type_sets.each do |iv, types|
            next if types.include?(:unknown)
            concrete = types - Set[:nil, :self_ivar]
            has_nil  = types.include?(:nil) || types.include?(:self_ivar)
            if concrete.size == 1 && @ti_user_class_names&.include?(concrete.first)
              cls = concrete.first
              result[iv] = has_nil ? [:class_or_nil, cls] : [:class, cls]
            elsif concrete.empty? && types == Set[:nil, :self_ivar]
              # Exactly {nil, self_ivar} — classic tree/list pattern (e.g. @left/@right).
              # Infer as self-typed: the ivar holds instances of this class or nil.
              result[iv] = [:class_or_nil, class_name]
            end
          end
          @class_typed_ivars[class_name] = result unless result.empty?
        end
      end

      # Walk AST collecting class type of each ivar assignment.
      def collect_ivar_class_types(node, ivar_type_sets, class_locals)
        return unless node
        case node
        when Ast::Sequence
          node.nodes.each { |n| collect_ivar_class_types(n, ivar_type_sets, class_locals) }
        when Ast::InstanceVariableWrite
          iv = ivar(node, :name)
          ty = ivar_assign_class_type(ivar(node, :value_node), class_locals)
          ivar_type_sets[iv] << ty
        when Ast::If
          collect_ivar_class_types(ivar(node, :then_node), ivar_type_sets, class_locals)
          collect_ivar_class_types(ivar(node, :else_node), ivar_type_sets, class_locals)
        when Ast::While, Ast::Until
          collect_ivar_class_types(ivar(node, :body_node), ivar_type_sets, class_locals)
        when Ast::Block
          collect_ivar_class_types(ivar(node, :body), ivar_type_sets, class_locals)
        when Ast::Rescue
          collect_ivar_class_types(ivar(node, :body), ivar_type_sets, class_locals)
        end
      end

      # Determine the class type of an expression for ivar assignment.
      # Returns: class Symbol (user class name), :nil, or :unknown.
      def ivar_assign_class_type(node, class_locals = {})
        case node
        when Ast::NilLiteral then :nil
        when Ast::MethodCall
          name = ivar(node, :name)
          recv = ivar(node, :receiver_node)
          if name == :new && recv.is_a?(Ast::ConstantRead)
            ivar(recv, :name)
          elsif recv.nil?
            # Self-call to accessor (e.g. right = self.right) — self-referential
            :self_ivar
          elsif recv.is_a?(Ast::InstanceVariableRead)
            # Accessor on an ivar (e.g. @root = @root.right) — self-referential
            :self_ivar
          else
            :unknown
          end
        when Ast::LocalVariableRead
          # Check TI class locals for the enclosing method
          cls = class_locals[ivar(node, :name)]
          if cls && @ti_user_class_names&.include?(cls)
            cls
          else
            # Optimistic: untyped locals assigned to ivars are likely same-class.
            # Crystal catches any real type mismatch at compile time.
            :self_ivar
          end
        when Ast::InstanceVariableRead
          # Reading another ivar — mark as self-referential (resolved in fixpoint)
          :self_ivar
        when Ast::Sequence
          node.nodes.empty? ? :unknown : ivar_assign_class_type(node.nodes.last, class_locals)
        else
          :unknown
        end
      end

      # Walk the execute block body for `ClassName.new(...)` calls and return
      # the merged positional param raw types, or nil if not found / inconsistent.
      def collect_class_new_arg_types(node, class_name)
        result = nil
        walk_class_new_calls(node, class_name) do |arg_types|
          result = if result.nil?
            arg_types
          else
            result.zip(arg_types).map { |a, b| a == b ? a : nil }
          end
        end
        result
      end

      def walk_class_new_calls(node, class_name, &block)
        return unless node
        case node
        when Ast::MethodCall
          recv = node.receiver_node
          args = node.arg_nodes || []
          if node.name == :new && recv.is_a?(Ast::ConstantRead) && ivar(recv, :name) == class_name
            block.call(args.map { |a| node_raw_type(a) })
          end
          args.each { |a| walk_class_new_calls(a, class_name, &block) }
          blk = node.instance_variable_get(:@block_node)
          walk_class_new_calls(blk&.body, class_name, &block) if blk
        when Ast::Sequence
          node.nodes.each { |n| walk_class_new_calls(n, class_name, &block) }
        when Ast::If
          walk_class_new_calls(ivar(node, :then_node), class_name, &block)
          walk_class_new_calls(ivar(node, :else_node), class_name, &block)
        when Ast::While, Ast::Until
          walk_class_new_calls(ivar(node, :body_node), class_name, &block)
        when Ast::ArrayLiteral
          node.instance_variable_get(:@element_nodes)&.each do |n|
            walk_class_new_calls(n, class_name, &block)
          end
        else
          %i[body_node value_node].each do |slot|
            next unless node.instance_variable_defined?(:"@#{slot}")
            child = node.instance_variable_get(:"@#{slot}")
            walk_class_new_calls(child, class_name, &block) if child.is_a?(Ast::Node)
          end
        end
      end

      # Walk an initialize body collecting ivar types from assignments.
      # Expects @typed_locals to be seeded with param types.
      def collect_ivar_assignments(node, ivar_types)
        return unless node
        case node
        when Ast::Sequence
          node.nodes.each { |n| collect_ivar_assignments(n, ivar_types) }
        when Ast::InstanceVariableWrite
          iv = ivar(node, :name)
          ty = node_raw_type(ivar(node, :value_node))
          update_ivar_type(ivar_types, iv, ty)
        when Ast::MultipleAssignment
          targets = ivar(node, :targets)
          value   = ivar(node, :value_node)
          # Handle ArrayLiteral RHS: @a, @b = expr_a, expr_b
          if value.is_a?(Ast::ArrayLiteral)
            elems = value.instance_variable_get(:@element_nodes) || []
            targets.each_with_index do |t, i|
              next unless t[0] == :ivar
              update_ivar_type(ivar_types, t[1], elems[i] ? node_raw_type(elems[i]) : nil)
            end
          end
        end
      end

      def update_ivar_type(ivar_types, iv, ty)
        return unless ty
        if !ivar_types.key?(iv)
          ivar_types[iv] = ty
        elsif ivar_types[iv] != ty
          ivar_types.delete(iv)
        end
      end
      end
    end
  end
end
