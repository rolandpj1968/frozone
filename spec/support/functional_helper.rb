require_relative 'vm_loader'

# Evaluate a Ruby snippet end-to-end through the Frozone VM.
# Returns the VM result object (IntegerObject, StringObject, etc.).
module FunctionalTestHelpers
  def run_ruby(code)
    Frozone::Vm::Vm.new.eval_snippet(code)
  end

  # ── result matchers ──────────────────────────────────────────────────────────
  # Each helper returns an RSpec `satisfy` matcher for the given VM type/value.

  def vm_int(n)
    satisfy("be IntegerObject(#{n})") { |r|
      r.is_a?(Frozone::Vm::IntegerObject) && r.raw == n
    }
  end

  def vm_string(s)
    satisfy("be StringObject(#{s.inspect})") { |r|
      r.is_a?(Frozone::Vm::StringObject) && r.raw == s
    }
  end

  def vm_symbol(sym)
    satisfy("be SymbolObject(:#{sym})") { |r|
      r.is_a?(Frozone::Vm::SymbolObject) && r.raw == sym
    }
  end

  def vm_nil
    satisfy("be NilObject::NIL") { |r| r.equal?(Frozone::Vm::NilObject::NIL) }
  end

  def vm_true
    satisfy("be TrueObject::TRUE") { |r| r.equal?(Frozone::Vm::TrueObject::TRUE) }
  end

  def vm_false
    satisfy("be FalseObject::FALSE") { |r| r.equal?(Frozone::Vm::FalseObject::FALSE) }
  end

  def vm_array(raw_values = nil)
    if raw_values
      satisfy("be ArrayObject#{raw_values.inspect}") { |r|
        r.is_a?(Frozone::Vm::ArrayObject) && r.raw.map(&:raw) == raw_values
      }
    else
      satisfy("be an ArrayObject") { |r| r.is_a?(Frozone::Vm::ArrayObject) }
    end
  end

  def vm_class(name)
    satisfy("be ClassObject(:#{name})") { |r|
      r.is_a?(Frozone::Vm::ClassObject) && r.name == Frozone::Vm::SymbolObject.from(name)
    }
  end
end

RSpec.configure do |config|
  config.include FunctionalTestHelpers

  # Load the standard library once for the entire suite.
  config.before(:suite) do
    Frozone::Vm::Vm.new.load_core
  end
end
