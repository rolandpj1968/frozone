# Soundness fence for TI predicate narrowing.
#
# ------------------------------------------------------------------
# The problem
# ------------------------------------------------------------------
#
# Flow-sensitive TI wants to narrow variables through predicate call
# sites — inside `if x.is_a?(Integer); ...; end` we'd like to type x
# as Integer in the then-branch. But `is_a?`, `kind_of?`,
# `instance_of?`, `nil?` are ordinary Ruby methods. Any class can
# override them to return arbitrary values. If we narrow x to Integer
# on the strength of `x.is_a?(Integer)` returning true, and x's class
# overrode `is_a?` to lie, generated code dispatches x through slots
# that assume an Integer memory layout it doesn't have — segfault or
# silent corruption.
#
# ------------------------------------------------------------------
# The fence
# ------------------------------------------------------------------
#
# Under closed-world we know every class's method table. This module
# provides the check: given a predicate name and a class (or the whole
# reachable set), is the predicate's body one of the *canonical*
# bodies snapshotted at end of load_core?
#
# Canonical bodies live in `Vm::CANONICAL_PREDICATE_BODIES` (see
# vm.rb). Identity comparison (`equal?`) catches:
#   - inherited canonicals (child class has no entry in its own table,
#     lookup walks up to Kernel — same body ref);
#   - `alias kind_of? is_a?` (aliased entries share their body ref);
#   - future overrides that go through `Method#alias_as` (which
#     preserves body identity).
# and rejects:
#   - any user `def is_a?(...); ...; end` (new AST → different body ref).
#
# ------------------------------------------------------------------
# Consumer API
# ------------------------------------------------------------------
#
# TI's fact generator asks two questions:
#   `class_uses_canonical?(cls, :is_a?)`
#     — narrow only if the RECEIVER's specific class is proven
#       canonical (local canonicity — safe even if some other class
#       overrides is_a?).
#   `globally_canonical?(all_classes, :is_a?)`
#     — narrow anywhere; the reachable set is override-free for this
#       predicate.
# Non-canonical → no fact emitted, no narrowing, sound conservative
# fallback.
require 'set'

module Frozone
  module Compiler
    module Analysis
      module PredicateCanonicity
        # Predicates TI will (eventually) narrow through. Kept as a
        # frozen list so tests and diagnostics can enumerate the set.
        NARROWING_PREDICATES = %i[is_a? kind_of? instance_of? nil?].freeze

        # Predicates whose semantics MUST be canonical — overriding
        # them breaks Ruby's own type-check contract (`x.is_a?(T)` is
        # supposed to mean "x's class inherits T", not "arbitrary
        # user-computed value"). We reject non-canonical overrides
        # loudly at compile time rather than silently mis-narrowing.
        # `==` / `eql?` are NOT in this set — their per-class override
        # is legitimate and the narrowing machinery handles them
        # type-directed.
        HARD_PREDICATES = %i[is_a? kind_of? instance_of? nil?].freeze

        # Raised by `assert_no_hard_overrides!` when a reachable class
        # overrides a HARD_PREDICATES entry with a non-canonical body.
        class OverrideError < StandardError; end

        class << self
          # True iff `body` is identity-equal to a captured canonical
          # for `name`. False if capture never ran (no canonical
          # available → refuse to trust) or body is nil.
          def body_canonical?(name, body)
            return false if body.nil?
            canonicals = Vm::CANONICAL_PREDICATE_BODIES[name]
            return false if canonicals.nil? || canonicals.empty?
            canonicals.include?(body)
          end

          # True iff `cls` resolves `name` via `lookup_method` to a
          # canonical body. Follows the ancestor chain — a class that
          # doesn't define `name` locally but inherits Kernel#is_a?
          # counts as canonical.
          def class_uses_canonical?(cls, name)
            return false unless cls.respond_to?(:lookup_method)
            m = cls.lookup_method(name)
            return false unless m.is_a?(Vm::Method)
            body_canonical?(name, m.body)
          end

          # True iff every class in `all_classes` whose *own*
          # methods_table defines `name` uses a canonical body.
          # Classes without a local entry inherit and are fine; we
          # only need to reject explicit overrides.
          def globally_canonical?(all_classes, name)
            return false unless Vm::CANONICAL_PREDICATE_BODIES.key?(name)
            (all_classes || {}).each_value do |cls|
              next unless cls.respond_to?(:methods_table)
              m = (cls.methods_table || {})[name]
              next if m.nil?
              return false unless m.is_a?(Vm::Method) && body_canonical?(name, m.body)
            end
            true
          end

          # Raise OverrideError if any reachable class overrides a
          # HARD_PREDICATES entry non-canonically. Called from the
          # compile pipeline before codegen. Message lists every
          # offender with its source_location.
          def assert_no_hard_overrides!(all_classes)
            offenders = HARD_PREDICATES.flat_map do |name|
              override_classes(all_classes, name).map { |cls| [name, cls] }
            end
            return if offenders.empty?
            lines = offenders.map do |name, cls|
              m = (cls.methods_table || {})[name]
              loc = (m.respond_to?(:source_location) && m.source_location) || '(unknown location)'
              cls_name = cls.respond_to?(:name) ? cls.name : cls.inspect
              "  #{cls_name}##{name} at #{loc}"
            end
            raise OverrideError, <<~MSG
              Predicate override(s) not supported — is_a?/kind_of?/instance_of?/nil?
              must have canonical semantics for TI to reason about type narrowing.
              Offenders:
              #{lines.join("\n")}
            MSG
          end

          # Classes in `all_classes` whose own methods_table defines a
          # non-canonical body for `name`. Returns a Set of the
          # ClassObjects themselves (caller may flat-name them). If
          # the set is empty, `name` is globally canonical.
          def override_classes(all_classes, name)
            Set.new.tap do |set|
              next unless Vm::CANONICAL_PREDICATE_BODIES.key?(name)
              (all_classes || {}).each_value do |cls|
                next unless cls.respond_to?(:methods_table)
                m = (cls.methods_table || {})[name]
                next if m.nil?
                next unless m.is_a?(Vm::Method)
                set << cls unless body_canonical?(name, m.body)
              end
            end
          end
        end
      end
    end
  end
end
