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
      # Populates @typed_params with {method_name => [:i64/:f64, ...]} for consistent sites.
      def collect_raw_call_sites(execute_block)
        return unless execute_block
        old_typed    = @typed_locals
        @typed_locals = infer_local_types(execute_block.body)
        raw_calls    = Hash.new { |h, k| h[k] = [] }
        walk_raw_free_calls(execute_block.body, raw_calls)
        @typed_locals = old_typed

        raw_calls.each do |name, call_type_lists|
          next if call_type_lists.empty?
          next unless call_type_lists.all? { |types| types.all? }      # all non-nil
          arities = call_type_lists.map(&:size).uniq
          next unless arities.size == 1                                  # consistent arity
          merged = call_type_lists.reduce { |a, b| a.zip(b).map { |ta, tb| ta == tb ? ta : nil } }
          @typed_params[name] = merged if merged&.all?
        end
      end

      def walk_raw_free_calls(node, raw_calls)
        return unless node
        case node
        when Ast::Sequence
          node.nodes.each { |n| walk_raw_free_calls(n, raw_calls) }
        when Ast::MethodCall
          recv = node.receiver_node
          name = node.name
          args = node.arg_nodes || []
          if recv.nil? && @user_methods.include?(name)
            raw_calls[name] << args.map { |a| node_raw_type(a) }
          end
          args.each { |a| walk_raw_free_calls(a, raw_calls) }
          blk = node.instance_variable_get(:@block_node)
          walk_raw_free_calls(blk.body, raw_calls) if blk&.respond_to?(:body) && blk.body
        when Ast::If
          walk_raw_free_calls(node.instance_variable_get(:@pred_node), raw_calls)
          walk_raw_free_calls(node.instance_variable_get(:@then_node), raw_calls)
          walk_raw_free_calls(node.instance_variable_get(:@else_node), raw_calls)
        when Ast::While, Ast::Until
          walk_raw_free_calls(node.instance_variable_get(:@condition_node), raw_calls)
          walk_raw_free_calls(node.instance_variable_get(:@body_node), raw_calls)
        else
          %i[body_node value_node then_node else_node condition_node].each do |slot|
            next unless node.instance_variable_defined?(:"@#{slot}")
            child = node.instance_variable_get(:"@#{slot}")
            walk_raw_free_calls(child, raw_calls) if child.is_a?(Ast::Node)
          end
          if node.instance_variable_defined?(:@arg_nodes)
            Array(node.instance_variable_get(:@arg_nodes)).each do |a|
              walk_raw_free_calls(a, raw_calls) if a.is_a?(Ast::Node)
            end
          end
        end
      end

      # For each method in @typed_params, tentatively assume same-type return,
      # then verify by walking the method body. Methods that fail verification
      # are removed from both @typed_params and @typed_method_returns.
      def collect_typed_method_returns
        return if @typed_params.empty?
        methods_table = @top_level_scope.instance_variable_get(:@methods_table) || {}

        # Tentative assignment (allows recursive calls to see a return type during verification)
        @typed_params.each do |name, param_types|
          @typed_method_returns[name] = param_types.first if param_types.uniq.size == 1
        end

        to_remove = []
        @typed_params.each do |name, param_types|
          method = methods_table[name]
          unless method.is_a?(Vm::Method) && method.body
            to_remove << name; next
          end
          # Only specialise methods with purely required params (no optionals/rest/kw)
          req = ivar(method, :required_params) || []
          unless req.size == param_types.size &&
                 ivar(method, :optional_params).to_a.empty? &&
                 ivar(method, :rest_param).nil?
            to_remove << name; next
          end

          old_typed     = @typed_locals
          @typed_locals = req.zip(param_types).to_h
          actual_return = infer_body_return_type(method.body)
          raw_safe      = body_all_raw_safe?(method.body)
          @typed_locals = old_typed

          unless actual_return == @typed_method_returns[name] && raw_safe
            to_remove << name
          end
        end

        to_remove.each { |n| @typed_params.delete(n); @typed_method_returns.delete(n) }
      end

      # Returns the raw Crystal type (:i64/:f64) of the last expression in a body,
      # or nil if it cannot be determined or is not a raw numeric type.
      def infer_body_return_type(body)
        return nil unless body
        case body
        when Ast::Sequence then infer_body_return_type(body.nodes.last)
        when Ast::If
          t = infer_body_return_type(ivar(body, :then_node))
          e = infer_body_return_type(ivar(body, :else_node))
          (t && t == e) ? t : nil
        when Ast::Return   then infer_body_return_type(ivar(body, :value_node))
        else               node_raw_type(body)
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
        when Ast::LocalVariableRead  then true
        when Ast::LocalVariableWrite then body_all_raw_safe?(ivar(node, :value_node))
        when Ast::Sequence           then node.nodes.all? { |n| body_all_raw_safe?(n) }
        when Ast::Return             then body_all_raw_safe?(ivar(node, :value_node))
        when Ast::If
          body_all_raw_safe?(ivar(node, :pred_node)) &&
            body_all_raw_safe?(ivar(node, :then_node)) &&
            body_all_raw_safe?(ivar(node, :else_node))
        when Ast::MethodCall
          name = ivar(node, :name)
          recv = ivar(node, :receiver_node)
          args = ivar(node, :arg_nodes) || []
          if recv.nil?
            # Free call — must be to a specialised method
            @typed_method_returns.key?(name) ? args.all? { |a| body_all_raw_safe?(a) } : false
          elsif (RawEmission::ARITH_OPS_UNBOX | CrystalEmitter::COMPARE_OPS).include?(name) && args.size == 1
            body_all_raw_safe?(recv) && body_all_raw_safe?(args[0])
          else
            false
          end
        else false
        end
      end

      # Emit a Crystal method with raw Int64/Float64 param and return types.
      # Only called when @typed_params[name] and @typed_method_returns[name] are set.
      def emit_specialized_vm_method(name, method)
        param_types = @typed_params[name]
        return_type = @typed_method_returns[name]
        req_params  = ivar(method, :required_params) || []
        return unless req_params.size == param_types.size

        cr = { i64: 'Int64', f64: 'Float64' }
        parts = req_params.zip(param_types).map { |p, ty| "#{crystal_local(p)} : #{cr[ty]}" }

        write "def #{crystal_method_name(name)}(#{parts.join(', ')}) : #{cr[return_type]}"
        emit_newline

        old_typed     = @typed_locals
        old_typed_arr = @typed_array_locals
        param_set     = req_params.to_set
        # Start with param types, add TI-inferred locals, then infer from literals.
        @typed_locals = req_params.zip(param_types).to_h
        (@ti_locals[name] || {}).each do |lname, ty|
          @typed_locals[lname] = ty unless param_set.include?(lname)
        end
        # Infer types from literal assignments for locals TI didn't cover
        infer_local_types(method.body).each do |lname, ty|
          @typed_locals[lname] ||= ty unless param_set.include?(lname)
        end
        # Populate typed array locals from TI (non-param only).
        @typed_array_locals = (@ti_arrays[name] || {}).reject { |k, _| param_set.include?(k) }
        indented { emit_raw_body(method.body) }
        @typed_locals       = old_typed
        @typed_array_locals = old_typed_arr

        emit_newline
        emit_indent
        write "end"
      end

      # Emit a specialized (typed) class method overload.
      # Like emit_specialized_vm_method but with `def self.` prefix and
      # class-keyed TI lookups.
      def emit_specialized_class_method(class_name, mname, method, raw_types, return_type, crystal_param_types: nil)
        req_params = ivar(method, :required_params) || []
        return unless req_params.size == raw_types.size

        cr = { i64: 'Int64', f64: 'Float64' }
        parts = req_params.each_with_index.map do |p, i|
          if raw_types[i]
            "#{crystal_local(p)} : #{cr[raw_types[i]]}"
          elsif crystal_param_types && crystal_param_types[i] && crystal_param_types[i] != 'RubyObject'
            "#{crystal_local(p)} : #{crystal_param_types[i]}"
          else
            "#{crystal_local(p)} : RubyObject"
          end
        end

        write "def self.#{crystal_method_name(mname)}(#{parts.join(', ')})"
        write " : #{cr[return_type]}" if return_type
        emit_newline

        old_typed       = @typed_locals
        old_typed_arr   = @typed_array_locals
        old_class_name  = @current_class_name
        @current_class_name = class_name
        param_set     = req_params.to_set
        mkey = [class_name, mname]
        # Start with param types
        @typed_locals = {}
        req_params.zip(raw_types).each { |p, ty| @typed_locals[p] = ty if ty }
        # Add TI-inferred locals
        (@ti_locals[mkey] || @ti_locals[mname] || {}).each do |lname, ty|
          @typed_locals[lname] = ty unless param_set.include?(lname)
        end
        infer_local_types(method.body).each do |lname, ty|
          @typed_locals[lname] ||= ty unless param_set.include?(lname)
        end
        @typed_array_locals = (@ti_arrays[mkey] || @ti_arrays[mname] || {}).reject { |k, _| param_set.include?(k) }
        # Register Array(Int64)/Array(Float64) params as native arrays
        @native_array_locals = {}
        if crystal_param_types
          req_params.each_with_index do |p, i|
            case crystal_param_types[i]
            when 'Array(Int64)'   then @native_array_locals[p] = :i64
            when 'Array(Float64)' then @native_array_locals[p] = :f64
            end
          end
        end
        # Always use raw body for specialized overloads
        indented { emit_raw_body(method.body) }
        @typed_locals       = old_typed
        @typed_array_locals = old_typed_arr
        @current_class_name = old_class_name

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
        params = (ivar(blk, :required_params) || []) + (ivar(blk, :optional_params) || []).map(&:first)
        params += [ivar(blk, :rest_param)].compact
        write "{ "
        unless params.empty?
          write "|#{params.map { |p| crystal_local(p) }.join(', ')}| "
        end
        old_rbp = @raw_block_params
        @raw_block_params = old_rbp.merge(params.map { |p| [p, :i64] }.to_h)
        emit(ivar(blk, :body))
        @raw_block_params = old_rbp
        write " }"
      end

      # Override: emit `for i in lo...hi` as a native Crystal integer range loop
      # when the iteration variable is typed :i64 in TI.
      def emit_for_loop(node)
        target = ivar(node, :target)
        if target[0] == :local
          name = target[1]
          if @current_block_params[name] == :i64
            coll = ivar(node, :collection_node)
            if coll.is_a?(Ast::RangeLiteral)
              lo   = ivar(coll, :begin_node)
              hi   = ivar(coll, :end_node)
              excl = ivar(coll, :exclusive)
              if node_raw_type(lo) == :i64 && node_raw_type(hi) == :i64
                write "("
                emit_raw(lo)
                write excl ? "..." : ".."
                emit_raw(hi)
                write ").each do |#{crystal_local(name)}|"
                emit_newline
                old_rbp = @raw_block_params
                @raw_block_params = old_rbp.merge(name => :i64)
                indented { emit(ivar(node, :body_node)) }
                @raw_block_params = old_rbp
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

      # Emit a method body in raw (unboxed) mode: structural nodes are handled
      # normally (if/sequence/assignments), expressions are emitted via emit_raw.
      def emit_raw_body(node)
        return unless node
        case node
        when Ast::Sequence
          node.nodes.each { |n| emit_indent; emit_raw_body(n); emit_newline }
        when Ast::If
          write "if "
          cond = ivar(node, :pred_node)
          if cond.is_a?(Ast::MethodCall) && (RawEmission::ARITH_OPS_UNBOX | CrystalEmitter::COMPARE_OPS).include?(ivar(cond, :name)) &&
             (ivar(cond, :arg_nodes) || []).size == 1
            recv = ivar(cond, :receiver_node)
            # Wrap embedded assignments in parens so (q1 = expr) != val
            # doesn't become q1 = (expr != val) due to Crystal precedence
            if contains_assignment?(recv)
              write "("; emit_raw(recv); write ")"
            else
              emit_raw(recv)
            end
            write " #{ivar(cond, :name)} "
            emit_raw((ivar(cond, :arg_nodes))[0])
          else
            emit_raw(cond)
          end
          emit_newline
          indented { emit_raw_body(ivar(node, :then_node)) }
          else_node = ivar(node, :else_node)
          if else_node
            emit_indent; write "else"; emit_newline
            indented { emit_raw_body(else_node) }
          end
          emit_indent; write "end"
        when Ast::While
          write "while "
          emit_raw(ivar(node, :condition_node))
          emit_newline
          indented { emit_raw_body(ivar(node, :body_node)) }
          emit_indent; write "end"
        when Ast::Until
          write "until "
          emit_raw(ivar(node, :condition_node))
          emit_newline
          indented { emit_raw_body(ivar(node, :body_node)) }
          emit_indent; write "end"
        when Ast::Return
          write "return "
          val = ivar(node, :value_node)
          emit_raw(val) if val
        when Ast::LocalVariableWrite
          # Delegate typed-array construction to emit_local_var_write (handles Array(T).new).
          # For scalar typed locals, emit assignment with raw RHS.
          name = ivar(node, :name)
          if @typed_array_locals[name]
            emit_local_var_write(node)
          else
            write "#{crystal_local(name)} = "
            emit_raw(ivar(node, :value_node))
          end
        else
          emit_raw(node)
        end
      end
      end
    end
  end
end
