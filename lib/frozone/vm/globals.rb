module Frozone
  module Vm
    # Global variables accessible via $name in Frozone code.
    # Keys are raw Ruby Symbols (e.g. :$LOAD_PATH). Values are VM objects.
    GLOBALS = {}
  end
end
