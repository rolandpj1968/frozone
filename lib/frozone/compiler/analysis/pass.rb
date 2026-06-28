# Abstract analysis pass.
#
# A pass is fully specified by three concerns:
#
#   #lattice      the algebraic domain (a Lattice instance)
#   #seed         Hash[Point → LatticeValue] — initial facts that the
#                 caller knows before any iteration
#   #transfer     given a point and its current value, compute the
#                 contributions this point makes to other points'
#                 values. Returns Hash[Point → LatticeValue]; the
#                 engine joins those into the global value map.
#
# Passes are pure: no engine awareness, no side state. The engine
# handles worklist scheduling, fixed-point detection, join arithmetic.
#
# The `lookup` argument to #transfer is a callable that takes a
# Point and returns the current lattice value at that point (or
# Lattice#bottom for an unseen point). Use it when transfer needs
# to inspect values at OTHER points — e.g. TI walking the return
# type of a callee. Simple analyses (reachability, NA eligibility)
# don't need it.

module Frozone
  module Compiler
    module Analysis
      class Pass
        def lattice = raise NotImplementedError, "#{self.class}#lattice"
        def seed = raise NotImplementedError, "#{self.class}#seed"

        def transfer(_point, _value, _lookup)
          raise NotImplementedError, "#{self.class}#transfer"
        end
      end
    end
  end
end
