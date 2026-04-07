# Instance variable type analysis for Codegen.
#
# Analyses all methods of user classes to determine ivar types:
# - Scalar typing: @x always holds Int64/Float64
# - Class typing: @root is Node | nil (X | nil pattern)
# - Constructor analysis: infer ivar types from initialize + call sites
#
# Dependencies: calls node_raw_type (RawEmission),
# user_source_location? (Codegen).

module Frozone
  module Compiler
    module CodegenSupport
      module IvarAnalysis
      KNOWN_BUILTIN_CLASSES = %i[Array Hash String Symbol Integer Float Range Regexp].to_set

      # Is this a known class name (user-defined or built-in)?
      def known_class?(name) = @gctx.user_class_names&.include?(name) || KNOWN_BUILTIN_CLASSES.include?(name)

      # Collect user numeric constants → raw type map.
      def collect_const_raw_types(scope)
        @gctx.const_raw_types = {}
        const_table = scope.constants_table || {}
        const_locs  = scope.constants_locations || {}
        const_table.each do |name, value|
          next if Codegen::SKIP_CONSTANTS.include?(name) || value.is_a?(Vm::ModuleObject)
          next unless user_source_location?(const_locs[name])
          case value
          when Vm::FloatObject   then @gctx.const_raw_types[name] = Type::F64
          when Vm::IntegerObject then @gctx.const_raw_types[name] = Type::I64
          when Vm::ArrayObject
            if value.raw.all? { |e| e.is_a?(Vm::IntegerObject) }
              @gctx.const_raw_types[name] = Type::ARRAY_I64
            elsif value.raw.all? { |e| e.is_a?(Vm::FloatObject) }
              @gctx.const_raw_types[name] = Type::ARRAY_F64
            end
          end
        end
      end

      # For each user-defined class: infer ivar types from constructor call sites
      # in the execute block + the initialize body.
      def collect_all_ivar_types(execute_block, scope)
        @gctx.typed_ivars = {}
        return unless execute_block

        scope.constants_table&.each do |name, value|
          next unless value.is_a?(Vm::ClassObject) && !Codegen::SKIP_CONSTANTS.include?(name)

          param_types = collect_class_new_arg_types(execute_block.body, name)
          next unless param_types&.all?

          init_method = value.methods_table&.fetch(:initialize, nil)
          next unless init_method.is_a?(Vm::Method) && init_method.body

          req_params = init_method.required_params || []
          next unless req_params.size == param_types.size

          old_typed     = @mctx.typed_locals
          @mctx.typed_locals = req_params.zip(param_types).to_h
          ivar_types    = {}
          collect_ivar_assignments(init_method.body, ivar_types)
          @mctx.typed_locals = old_typed

          @gctx.typed_ivars[name] = ivar_types unless ivar_types.empty?
        end
      end

      # Recursively collect user-defined classes (including nested classes)
      def collect_user_classes_recursive(scope, result)
        (scope.constants_table || {}).each do |name, val|
          next if Codegen::SKIP_CONSTANTS.include?(name)
          if val.is_a?(Vm::ModuleObject)  # includes ClassObject (subclass)
            result[name] = val
            collect_user_classes_recursive(val, result)
          end
        end
      end

      # Scan all methods of each user class for ivar assignments, collecting
      # the set of class types assigned. Produces @gctx.class_typed_ivars entries
      # for ivars with pattern {UserClass} or {UserClass, NilClass}.
      def collect_class_typed_ivars(scope)
        @gctx.class_typed_ivars = {}
        collect_class_typed_ivars_from(scope)
      end

      def collect_class_typed_ivars_from(scope)
        scope.constants_table&.each do |class_name, value|
          next unless value.is_a?(Vm::ModuleObject) && !Codegen::SKIP_CONSTANTS.include?(class_name)
          collect_class_typed_ivars_from(value)  # recurse into nested modules/classes
          next unless value.is_a?(Vm::ClassObject)  # only collect ivars for classes
          methods = value.methods_table || {}
          next unless methods.any? { |_, m| m.is_a?(Vm::Method) && user_source_location?(m.source_location) }

          # Collect all ivar assignment types across ALL methods. Skip
          # attr_accessor-generated setters: their `@x = v` body writes
          # `:unknown` (v is a param) which poisons the analysis.
          ivar_type_sets = Hash.new { |h, k| h[k] = Set.new }
          methods.each do |mname, method|
            next unless method.is_a?(Vm::Method) && method.body
            next if accessor_method?(method)
            mkey = [class_name, mname]
            method_class_locals = @gctx.class_locals[mkey] || {}
            method_params = Set.new((method.required_params || []) + (method.instance_variable_get(:@optional_params) || []).map(&:first))
            collect_ivar_class_types(method.body, ivar_type_sets, method_class_locals, param_names: method_params)
          end

          # Also scan setter calls (obj.left = val) from any method
          accessor_names = methods.keys.select { |n| n.to_s.end_with?('=') && n != :initialize }.map { |n| n.to_s.chomp('=').to_sym }.to_set
          unless accessor_names.empty?
            # Scan ALL class instance methods for setter calls to this class's ivars
            @gctx.user_class_names&.each do |cn|
              scope = lookup_vm_class(cn)
              (scope&.methods_table || {}).each do |_, m|
                next unless m.is_a?(Vm::Method) && m.body
                walk_setter_ivar_types(m.body, class_name, accessor_names, ivar_type_sets)
              end
            end
          end

          # Resolve: {ClassName} → [:class, name], {ClassName, :nil} → [:class_or_nil, name]
          # :self_ivar means the value comes from another ivar/accessor of the same
          # class — compatible with whatever class type is already identified.
          result = {}
          ivar_type_sets.each do |iv, types|
            next if types.include?(:unknown)
            concrete = types - Set[:nil, :self_ivar]
            has_nil  = types.include?(:nil) || types.include?(:self_ivar)
            if concrete.size == 1 && known_class?(concrete.first)
              cls = concrete.first
              result[iv] = has_nil ? [:class_or_nil, cls] : [:class, cls]
            elsif concrete.empty? && types.include?(:self_ivar)
              # All concrete assignments are self-referential ({self_ivar} or
              # {nil, self_ivar}) — tree/list pattern. Always nullable since
              # default param values or nil assignments are common.
              result[iv] = [:class_or_nil, class_name]
            end
          end
          @gctx.class_typed_ivars[class_name] = result unless result.empty?
        end
      end

      # Walk AST collecting class type of each ivar assignment.
      def collect_ivar_class_types(node, ivar_type_sets, class_locals, param_names: nil)
        return unless node
        case node
        when Ast::Sequence
          node.nodes.each { |n| collect_ivar_class_types(n, ivar_type_sets, class_locals, param_names: param_names) }
        when Ast::InstanceVariableWrite
          iv = node.name
          ty = ivar_assign_class_type(node.value_node, class_locals, param_names: param_names)
          ivar_type_sets[iv] << ty
        when Ast::If
          collect_ivar_class_types(node.then_node, ivar_type_sets, class_locals, param_names: param_names)
          collect_ivar_class_types(node.else_node, ivar_type_sets, class_locals, param_names: param_names)
        when Ast::While, Ast::Until
          collect_ivar_class_types(node.body_node, ivar_type_sets, class_locals, param_names: param_names)
        when Ast::Block
          collect_ivar_class_types(node.body, ivar_type_sets, class_locals, param_names: param_names)
        when Ast::Rescue
          collect_ivar_class_types(node.body, ivar_type_sets, class_locals, param_names: param_names)
        end
      end

      # Determine the class type of an expression for ivar assignment.
      # Returns: class Symbol (user/builtin class name), :nil, :self_ivar, or :unknown.
      # Walk for setter calls: obj.attr= val where obj is typed as class_name
      def walk_setter_ivar_types(node, class_name, accessor_names, ivar_type_sets)
        return unless node
        if node.is_a?(Ast::AttributeWrite)
          attr = node.name.to_s.chomp('=').to_sym
          if accessor_names.include?(attr)
            # Value is self-referential if it comes from same-class ivar/accessor
            ivar_type_sets[:"@#{attr}"] << :self_ivar
          end
        end
        node.children.each { |c| walk_setter_ivar_types(c, class_name, accessor_names, ivar_type_sets) }
      end

      def ivar_assign_class_type(node, class_locals = {}, param_names: nil)
        case node
        when Ast::NilLiteral then :nil
        when Ast::IntegerLiteral then :Integer
        when Ast::FloatLiteral then :Float
        when Ast::StringLiteral, Ast::InterpolatedString then :String
        when Ast::SymbolLiteral then :Symbol
        when Ast::ArrayLiteral then :Array
        when Ast::HashLiteral then :Hash
        when Ast::RangeLiteral then :Range
        when Ast::MethodCall
          name = node.name
          recv = node.receiver_node
          if name == :new && recv.is_a?(Ast::ConstantRead)
            recv.name  # Returns class name for both user and built-in
          elsif recv.nil?
            :self_ivar
          elsif recv.is_a?(Ast::InstanceVariableRead)
            :self_ivar
          else
            :unknown
          end
        when Ast::LocalVariableRead
          name = node.name
          cls = class_locals[name]
          if cls
            cls_sym = cls.is_a?(Array) ? cls[0] : cls
            (@gctx.user_class_names&.include?(cls_sym) || KNOWN_BUILTIN_CLASSES.include?(cls_sym)) ? cls_sym : :self_ivar
          elsif param_names&.include?(name)
            :unknown  # constructor/method params store arbitrary values
          else
            :self_ivar  # untyped locals likely derived from self's ivars
          end
        when Ast::InstanceVariableRead
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
        if node.is_a?(Ast::MethodCall) && node.name == :new &&
           node.receiver_node.is_a?(Ast::ConstantRead) && node.receiver_node.name == class_name
          block.call((node.arg_nodes || []).map { |a| node_raw_type(a) })
        end
        node.children.each { |c| walk_class_new_calls(c, class_name, &block) }
      end

      # Walk an initialize body collecting ivar types from assignments.
      # Expects @mctx.typed_locals to be seeded with param types.
      def collect_ivar_assignments(node, ivar_types)
        return unless node
        case node
        when Ast::Sequence
          node.nodes.each { |n| collect_ivar_assignments(n, ivar_types) }
        when Ast::InstanceVariableWrite
          iv = node.name
          ty = node_raw_type(node.value_node)
          update_ivar_type(ivar_types, iv, ty)
        when Ast::MultipleAssignment
          targets = node.targets
          value   = node.value_node
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
