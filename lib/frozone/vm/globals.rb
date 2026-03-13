module Frozone
  module Vm
    # Global variables accessible via $name in Frozone code.
    # Keys are raw Ruby Symbols (e.g. :$LOAD_PATH). Values are VM objects.
    GLOBALS = {}

    # Global variable aliases: $new => $original
    # When a name is in GLOBAL_ALIASES, reads/writes are redirected to the canonical name.
    GLOBAL_ALIASES = {}

    # Emit a warning to VM's $stderr (may be replaced by mspec's IOStub).
    def self.emit_warning(context, msg)
      stderr_vm = GLOBALS[:"$stderr"]
      return unless stderr_vm
      str_obj = StringObject.new("warning: #{msg}")
      stderr_vm.dispatch(context, :puts, [str_obj], {})
    rescue StandardError
      # Suppress any errors during warning emission
    end
  end
end
