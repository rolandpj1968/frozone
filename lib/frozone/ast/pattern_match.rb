require_relative 'node'
require_relative '../vm/nil_object'

# Pattern matching implementation for Frozone.
#
# Covers:
#   case x; in Pattern; body; end       (CaseMatchNode)
#   expr => Pattern                      (MatchRequiredNode)
#   expr in Pattern                      (MatchPredicateNode)
#
# Patterns (internal representation — built at parse time):
#   Pattern::Literal    — literal value (matched via ===)
#   Pattern::LocalBind  — bare local variable (always matches, binds value)
#   Pattern::Wildcard   — _ (always matches, no binding)
#   Pattern::Pin        — ^var or ^(expr)
#   Pattern::Alternation — left | right
#   Pattern::Capture    — sub_pattern => var
#   Pattern::Array      — [requireds..., *rest, posts...]  has_rest=true even if unnamed
#   Pattern::Find       — [*pre, requireds..., *post]
#   Pattern::Hash       — {key: sub_pattern, ...}

module Frozone
  module Ast

    # --------------------------------------------------------------------------
    # Internal pattern data structures (plain Ruby structs, not AST nodes)
    # --------------------------------------------------------------------------
    module Pattern
      Literal = Struct.new(:node)                                             # evaluatable node matched via ===
      LocalBind = Struct.new(:name, :depth)                                    # bare lvar — always matches, binds
      Wildcard = Struct.new(:keyword_singleton)                                # _ (anonymous)
      Pin = Struct.new(:node)                                             # ^expr (node is Ast::Node)
      Alternation = Struct.new(:left, :right)
      Capture = Struct.new(:sub_pattern, :name, :depth)                      # sub_pattern => var
      # constant is an Ast::Node or nil; has_rest=true if * present (even unnamed)
      Array = Struct.new(:constant, :requireds, :has_rest, :rest_name, :rest_depth, :posts)
      Find = Struct.new(:constant, :left_name, :left_depth, :requireds, :right_name, :right_depth)
      # rest_name=:__no_extra_keys__ means **nil (reject extra keys)
      Hash = Struct.new(:constant, :pairs, :rest_name, :rest_depth)       # pairs=[{key:, pattern:}]

      WILDCARD = Wildcard.new(:_)
    end

    # --------------------------------------------------------------------------
    # Core matching logic — shared by all three forms
    # --------------------------------------------------------------------------
    module PatternMatchLogic
      # Try to match `value` against `pattern`. Collects variable bindings into
      # `bindings` hash keyed by [name, depth]. Returns true on match, false on
      # mismatch. Never raises on mismatch.
      # dcache: per-case-expression cache of deconstruct results, keyed by value object_id.
      def pattern_match?(pattern, value, context, bindings, dcache = nil)
        case pattern
        when Pattern::Wildcard
          true

        when Pattern::LocalBind
          bindings[[pattern.name, pattern.depth]] = value
          true

        when Pattern::Pin
          # Pin reads the expression — which may reference variables already bound
          # in this arm's bindings. Apply them temporarily into the context frame
          # so the expression can read them, then restore.
          with_temp_bindings(bindings, context) do
            pinned = pattern.node.evaluate(context)
            pinned.dispatch(context, :===, [value], {}, nil, private_ok: true).truthy?
          end

        when Pattern::Literal
          pat_val = pattern.node.evaluate(context)
          pat_val.dispatch(context, :===, [value], {}, nil, private_ok: true).truthy?

        when Pattern::Alternation
          left_bindings = {}
          if pattern_match?(pattern.left, value, context, left_bindings, dcache)
            bindings.merge!(left_bindings)
            true
          else
            pattern_match?(pattern.right, value, context, bindings, dcache)
          end

        when Pattern::Capture
          if pattern_match?(pattern.sub_pattern, value, context, bindings, dcache)
            bindings[[pattern.name, pattern.depth]] = value
            true
          else
            false
          end

        when Pattern::Array
          match_array_pattern(pattern, value, context, bindings, dcache)

        when Pattern::Find
          match_find_pattern(pattern, value, context, bindings, dcache)

        when Pattern::Hash
          match_hash_pattern(pattern, value, context, bindings)

        else
          false
        end
      end

      def match_array_pattern(pattern, value, context, bindings, dcache = nil)
        # Check constant constraint via ===
        if pattern.constant
          klass = pattern.constant.evaluate(context)
          return false unless klass.dispatch(context, :===, [value], {}, nil, private_ok: true).truthy?
        end

        # Call deconstruct — always, even on Array objects (MRI spec requires this).
        # Cache per value (MRI only calls #deconstruct once across multiple arms).
        arr = call_deconstruct(value, context, dcache)
        return false if arr.nil?

        n_req = pattern.requireds.length
        n_post = pattern.posts.length

        len_obj = arr.dispatch(context, :length, [], {}, nil, private_ok: true)
        return false unless len_obj.is_a?(Vm::IntegerObject)
        arr_len = len_obj.raw

        if pattern.has_rest
          return false if arr_len < n_req + n_post
        else
          return false if arr_len != n_req + n_post
        end

        # Match requireds (from the left)
        n_req.times do |i|
          elem = arr.dispatch(context, :[], [Vm::IntegerObject.new(i)], {}, nil, private_ok: true)
          return false unless pattern_match?(pattern.requireds[i], elem, context, bindings, dcache)
        end

        # Match posts (from the right)
        n_post.times do |i|
          idx = arr_len - n_post + i
          elem = arr.dispatch(context, :[], [Vm::IntegerObject.new(idx)], {}, nil, private_ok: true)
          return false unless pattern_match?(pattern.posts[i], elem, context, bindings, dcache)
        end

        # Bind rest if named
        if pattern.rest_name
          rest_elems = (n_req...(arr_len - n_post)).map do |i|
            arr.dispatch(context, :[], [Vm::IntegerObject.new(i)], {}, nil, private_ok: true)
          end
          bindings[[pattern.rest_name, pattern.rest_depth]] = Vm::ArrayObject.new(rest_elems)
        end

        true
      end

      def match_find_pattern(pattern, value, context, bindings, dcache = nil)
        if pattern.constant
          klass = pattern.constant.evaluate(context)
          return false unless klass.dispatch(context, :===, [value], {}, nil, private_ok: true).truthy?
        end

        arr = call_deconstruct(value, context, dcache)
        return false if arr.nil?

        len_obj = arr.dispatch(context, :length, [], {}, nil, private_ok: true)
        return false unless len_obj.is_a?(Vm::IntegerObject)
        arr_len = len_obj.raw
        n_req = pattern.requireds.length
        return false if arr_len < n_req

        (0..(arr_len - n_req)).each do |start|
          sub_bindings = {}
          matched = n_req.times.all? do |i|
            elem = arr.dispatch(context, :[], [Vm::IntegerObject.new(start + i)], {}, nil, private_ok: true)
            pattern_match?(pattern.requireds[i], elem, context, sub_bindings, dcache)
          end
          next unless matched

          if pattern.left_name
            pre = (0...start).map { |i| arr.dispatch(context, :[], [Vm::IntegerObject.new(i)], {}, nil, private_ok: true) }
            sub_bindings[[pattern.left_name, pattern.left_depth]] = Vm::ArrayObject.new(pre)
          end

          if pattern.right_name
            post_start = start + n_req
            post = (post_start...arr_len).map { |i| arr.dispatch(context, :[], [Vm::IntegerObject.new(i)], {}, nil, private_ok: true) }
            sub_bindings[[pattern.right_name, pattern.right_depth]] = Vm::ArrayObject.new(post)
          end

          bindings.merge!(sub_bindings)
          return true
        end

        false
      end

      def match_hash_pattern(pattern, value, context, bindings)
        if pattern.constant
          klass = pattern.constant.evaluate(context)
          return false unless klass.dispatch(context, :===, [value], {}, nil, private_ok: true).truthy?
        end

        # Build keys list for deconstruct_keys
        keys_list = pattern.pairs.map { |pair| Vm::SymbolObject.from(pair[:key]) }
        keys_arr = Vm::ArrayObject.new(keys_list)

        has_rest = !pattern.rest_name.nil?
        # Named **rest passes nil (get all keys); unnamed ** passes the key list
        named_rest_arg = has_rest &&
                         pattern.rest_name != :__no_extra_keys__ &&
                         pattern.rest_name != :__unnamed_rest__
        dk_arg = named_rest_arg ? Vm::NilObject::NIL : keys_arr

        begin
          deconstructed = value.dispatch(context, :deconstruct_keys, [dk_arg], {}, nil, private_ok: true)
        rescue Vm::FrozoneException => e
          return false if e.frozone_class_name.to_s == "NoMethodError"
          raise
        end

        return false if deconstructed.is_a?(Vm::NilObject)
        unless deconstructed.is_a?(Vm::HashObject)
          raise Vm::FrozoneException.make(:TypeError, "deconstruct_keys must return Hash")
        end

        # Match each key's sub-pattern; key must exist in the hash
        pattern.pairs.each do |pair|
          sym_key = Vm::SymbolObject.from(pair[:key])
          key_present = deconstructed.dispatch(context, :key?, [sym_key], {}, nil, private_ok: true).truthy?
          return false unless key_present

          elem = deconstructed.dispatch(context, :[], [sym_key], {}, nil, private_ok: true)
          return false unless pattern_match?(pair[:pattern], elem, context, bindings)
        end

        # MRI rule: empty pattern {} (no pairs, no rest) requires empty hash.
        # {**nil} also rejects extra keys. {**} / {**rest} allow extra keys.
        no_extra_keys = (pattern.pairs.empty? && !has_rest) ||
                        pattern.rest_name == :__no_extra_keys__

        if no_extra_keys
          matched_keys = pattern.pairs.map { |p| Vm::SymbolObject.from(p[:key]) }
          deconstructed.raw.each_key do |k|
            return false unless matched_keys.any? { |mk| mk.raw == k.raw }
          end
          return true
        end

        # Named **rest: collect extra keys into a hash binding (skip unnamed/sentinel variants)
        named_rest = has_rest &&
                     pattern.rest_name != :__no_extra_keys__ &&
                     pattern.rest_name != :__unnamed_rest__
        if named_rest
          matched_keys = pattern.pairs.map { |p| Vm::SymbolObject.from(p[:key]) }
          rest_hash = Vm::HashObject.new
          deconstructed.raw.each do |k, v|
            rest_hash[k] = v unless matched_keys.any? { |mk| mk.raw == k.raw }
          end
          bindings[[pattern.rest_name, pattern.rest_depth]] = rest_hash
        end

        true
      end

      # dcache: optional Hash keyed by Ruby object_id — caches deconstruct results
      # so #deconstruct is called at most once per value per case/in expression.
      # nil sentinel :__no_deconstruct__ means NoMethodError was raised.
      def call_deconstruct(value, context, dcache = nil)
        key = value.object_id
        if dcache&.key?(key)
          cached = dcache[key]
          return nil if cached == :__no_deconstruct__
          return cached
        end

        begin
          result = value.dispatch(context, :deconstruct, [], {}, nil, private_ok: true)
        rescue Vm::FrozoneException => e
          cls = e.frozone_class_name.to_s
          if cls == "NoMethodError"
            dcache[key] = :__no_deconstruct__ if dcache
            return nil
          end
          raise
        end

        unless result.is_a?(Vm::ArrayObject)
          raise Vm::FrozoneException.make(:TypeError, "deconstruct must return Array")
        end
        dcache[key] = result if dcache
        result
      end

      # Temporarily apply bindings to context, yield, then restore.
      # Used so pin expressions and guards can see already-bound pattern variables.
      def with_temp_bindings(bindings, context)
        saved = bindings.map do |(name, depth), val|
          frame = context.frame.frame_at_depth(depth)
          old = frame.get_local(name)  # nil if not set — acceptable since locals default to nil
          frame.set_local(name, val)
          [[name, depth], old]
        end.to_h
        begin
          yield
        ensure
          saved.each do |(name, depth), old|
            context.frame.frame_at_depth(depth).set_local(name, old)
          end
        end
      end

      def apply_bindings(bindings, context)
        bindings.each do |(name, depth), val|
          context.frame.frame_at_depth(depth).set_local(name, val)
        end
      end

      def no_matching_pattern_error(value, context)
        begin
          msg = value.dispatch(context, :inspect, [], {}, nil, private_ok: true)
          msg = msg.is_a?(Vm::StringObject) ? msg.raw : value.to_s
        rescue
          msg = value.to_s
        end
        Vm::FrozoneException.make(:NoMatchingPatternError, msg)
      end
    end

    # --------------------------------------------------------------------------
    # case x; in Pattern; body; end
    # --------------------------------------------------------------------------
    class PatternMatch < Node
      include PatternMatchLogic

      def initialize(predicate, arms, else_node)
        @predicate = predicate
        @arms = arms
        @else_node = else_node
      end

      def children = [@predicate, *@arms.flat_map { |a| [a[:guard], a[:body]] }, @else_node].compact
      def to_s = "case_match(#{@predicate}, #{@arms.length} arms)"

      def evaluate(context)
        subject = @predicate.evaluate(context)
        dcache = {}

        @arms.each do |arm|
          bindings = {}
          next unless pattern_match?(arm[:pattern], subject, context, bindings, dcache)

          # Apply bindings before guard so guard can read pattern variables
          guard_ok =
            if arm[:guard]
              with_temp_bindings(bindings, context) { arm[:guard].evaluate(context).truthy? }
            else
              true
            end
          next unless guard_ok

          apply_bindings(bindings, context)
          return arm[:body] ? arm[:body].evaluate(context) : Vm::NilObject::NIL
        end

        return @else_node.evaluate(context) if @else_node

        raise no_matching_pattern_error(subject, context)
      end
    end

    # --------------------------------------------------------------------------
    # expr => Pattern  (raises NoMatchingPatternError on mismatch)
    # --------------------------------------------------------------------------
    class MatchRequired < Node
      include PatternMatchLogic

      def initialize(value_node, pattern)
        @value_node = value_node
        @pattern = pattern
      end

      def children = [@value_node]
      def to_s = "match_required(#{@value_node})"

      def evaluate(context)
        value = @value_node.evaluate(context)
        bindings = {}

        unless pattern_match?(@pattern, value, context, bindings)
          raise no_matching_pattern_error(value, context)
        end

        apply_bindings(bindings, context)
        value
      end
    end

    # --------------------------------------------------------------------------
    # expr in Pattern  (returns true/false, no exception)
    # --------------------------------------------------------------------------
    class MatchPredicate < Node
      include PatternMatchLogic

      def initialize(value_node, pattern)
        @value_node = value_node
        @pattern = pattern
      end

      def children = [@value_node]
      def to_s = "match_predicate(#{@value_node})"

      def evaluate(context)
        value = @value_node.evaluate(context)
        bindings = {}

        if pattern_match?(@pattern, value, context, bindings)
          apply_bindings(bindings, context)
          Vm::TrueObject::TRUE
        else
          Vm::FalseObject::FALSE
        end
      end
    end

  end
end
