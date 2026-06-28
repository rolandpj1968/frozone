# Abstract analysis pass.
#
# Terminology:
#   Node  — a program entity that the analysis ascribes a lattice value
#           to: an AST expression, a class, a method, a constant binding,
#           etc. (The dataflow literature calls these "program points";
#           we use "node" to avoid conflating with lattice elements,
#           which are also called "points" in lattice theory.)
#   LatticeValue — an element of the lattice (`:reachable`, `Integer`,
#                  `Universal`, etc.)
#   The analysis result is a function Node → LatticeValue
#   (`Hash[Node → LatticeValue]` in code).
#
# A pass is fully specified by three concerns:
#
#   #lattice      the algebraic domain (a Lattice instance)
#   #seed         Hash[Node → LatticeValue] — initial facts that the
#                 caller knows before any iteration
#   #transfer     visit one node and return a TransferResult with
#                 two optional components:
#                   self_value — new value for THIS node (pull-side)
#                   pushes     — contributions to OTHER nodes (push-side)
#
#                 Use the convenience constructors:
#                   TransferResult.push(pushes_hash)         # pure push
#                   TransferResult.pull(new_self_value)      # pure pull
#                   TransferResult.both(self_value:, pushes:)  # bipolar
#                   TransferResult::EMPTY                    # no-op
#
# Pure-push passes (Reachability, NA eligibility, leaf-class,
# try-frame, visibility): each node, when reached, declares
# contributions to other nodes. self_value stays nil.
#
# Pure-pull passes (most of TI): each node's value is derived from
# its upstream feeders read via `lookup`. pushes stays empty.
#
# Bipolar passes (TI at MethodCall nodes): args push contributions to
# callee param bindings; return type pulls from callee return.
#
# Passes are pure: no engine awareness, no side state. The engine
# handles worklist scheduling, fixed-point detection, join arithmetic.
#
# The `lookup` argument to #transfer is a callable that takes a
# Node and returns the current lattice value at that node (or
# Lattice#bottom for an unseen node). Pull-style transfers call
# lookup; pure-push transfers usually don't.

module Frozone
  module Compiler
    module Analysis
      class Pass
        def lattice = raise NotImplementedError, "#{self.class}#lattice"
        def seed = raise NotImplementedError, "#{self.class}#seed"

        def transfer(_node, _value, _lookup)
          raise NotImplementedError, "#{self.class}#transfer"
        end
      end
    end
  end
end
