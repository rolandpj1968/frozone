module Frozone
  module Vm
    # Global variables accessible via $name in Frozone code.
    # Keys are raw Ruby Symbols (e.g. :$LOAD_PATH). Values are VM objects.
    GLOBALS = {}

    # Global variable aliases: $new => $original
    # When a name is in GLOBAL_ALIASES, reads/writes are redirected to the canonical name.
    GLOBAL_ALIASES = {}

    # Emit a warning to VM's $stderr (may be replaced by mspec's IOStub).
    # Optional +location+ is a "file:line" string prepended as "file:line: warning: msg".
    def self.emit_warning(context, msg, location: nil)
      stderr_vm = GLOBALS[:"$stderr"]
      return unless stderr_vm
      prefix = location ? "#{location}: " : ""
      str_obj = StringObject.new("#{prefix}warning: #{msg}")
      stderr_vm.dispatch(context, :puts, [str_obj], {})
    rescue StandardError
      # Suppress any errors during warning emission
    end

    # Trigger Module#const_added callback on scope when a constant named +name+ is added.
    def self.trigger_const_added(context, scope, name)
      return unless scope.is_a?(ModuleObject)
      scope.dispatch(context, :const_added, [SymbolObject.from(name)], {}, nil, private_ok: true)
    rescue FrozoneException
      # ignore errors (e.g. NoMethodError if const_added is not defined or raises)
    rescue StandardError
      # ignore MRI-level errors too
    end
  end
end
