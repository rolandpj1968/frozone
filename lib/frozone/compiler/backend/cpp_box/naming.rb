# Naming constants for emitted C++ artifacts. Kept in a dependency-free
# file so early consumers (runtime/universe.rb, which loads before the
# VM/reachability stack) can reach them without pulling the whole
# compiler stack.
#
# Reachability re-exports `EIG_SUFFIX` (and the eigenclass_name /
# eigenclass_flat helpers built on top) for legacy callers; the source
# of truth lives here.

module Frozone
  module Compiler
    module Backend
      module CppBox
        # Suffix appended to a class's flat name to form its eigenclass
        # struct's C++ identifier. Nod to the Eiger's Nordwand — pick
        # any 3-letter thing you like; it just has to be unique across
        # every non-eigenclass name in the closed world (task #216
        # renamed from `_eigenclass` for compactness).
        EIG_SUFFIX = "_eig"
      end
    end
  end
end
