module Frozone
  module Vm
    # Global variables accessible via $name in Frozone code.
    # Keys are raw Ruby Symbols (e.g. :$LOAD_PATH). Values are VM objects.
    GLOBALS = {}

    # Global variable aliases: $new => $original
    # When a name is in GLOBAL_ALIASES, reads/writes are redirected to the canonical name.
    GLOBAL_ALIASES = {}

    # Emit a warning via Warning.warn (routes through user-overrideable Warning.warn).
    # Optional +location+ is a "file:line" string prepended as "file:line: warning: msg".
    # Optional +category+ is a Symbol passed as keyword to Warning.warn.
    def self.emit_warning(context, msg, location: nil, category: nil)
      return unless context
      prefix = location ? "#{location}: " : ""
      full_msg = StringObject.new("#{prefix}warning: #{msg}\n")
      warning_mod = Core::OBJECT_CLASS.get_constant(:Warning)
      if warning_mod
        kw_args = category ? { category: SymbolObject.from(category) } : {}
        warning_mod.dispatch(context, :warn, [full_msg], kw_args)
      else
        stderr_vm = GLOBALS[:"$stderr"]
        return unless stderr_vm
        stderr_vm.dispatch(context, :write, [full_msg], {})
      end
    rescue StandardError, FrozoneException
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
