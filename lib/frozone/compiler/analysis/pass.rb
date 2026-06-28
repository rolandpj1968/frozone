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
#   #transfer     given a node and its current value, compute the
#                 contributions this node makes to other nodes'
#                 values. Returns Hash[Node → LatticeValue]; the
#                 engine joins those into the global value map.
#
# Passes are pure: no engine awareness, no side state. The engine
# handles worklist scheduling, fixed-point detection, join arithmetic.
#
# The `lookup` argument to #transfer is a callable that takes a
# Node and returns the current lattice value at that node (or
# Lattice#bottom for an unseen node). Use it when transfer needs
# to inspect values at OTHER nodes — e.g. TI walking the return
# type of a callee. Simple analyses (reachability, NA eligibility)
# don't need it.

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
