# Regression: MainObject's inline method emissions
# (write_universal_method / write_natural_arity_method /
# write_multi_arity_method / write_kw_unset_method in method_emitter.rb)
# do not emit the visibility prologue, so explicit-other dispatch to a
# private top-level def lands in the body without ever checking
# g_caller_self.
#
# Out-of-line emissions (build_natural_arity_override etc. in
# emitter.rb) DO call visibility_prologue_text — so Object's overlay
# copy of the same def has the check, but MainObject's NA-shape slot
# does not. Virtual dispatch via BasicObject* picks MainObject's
# (no-check) override.
#
# To exercise the gap, each name must be P4 (mixed-visibility). A P2
# (all-private) name would static-raise at the call site before
# dispatch even happens, masking the bug. We add a public def of the
# same name on a "VariantPublic*" class so the survey marks the name P4.

$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

# ---- Class defs must be load-phase under closed-world ----

# Public variant per name — forces P4 (mixed visibility) on every name
# so the call site emits the dynamic wrap+prologue path (instead of a
# static raise_private_call for P2 all-private names).
class VariantPublicNa
  def top_secret_na(x) = "public na: #{x}"
end

class VariantPublicMulti
  def top_secret_multi(x, y = 0) = "public multi: #{x} #{y}"
end

class VariantPublicKw
  def top_secret_kw(x, key: nil) = "public kw: #{x} key=#{key}"
end

class VariantPublicUniversal
  def top_secret_universal(*args) = "public universal: #{args}"
end

class Other
  def call_na(obj)         = obj.top_secret_na(42)
  def call_multi_one(obj)  = obj.top_secret_multi(11)
  def call_multi_two(obj)  = obj.top_secret_multi(11, 22)
  def call_kw(obj)         = obj.top_secret_kw(33, key: 7)
  def call_universal(obj)  = obj.top_secret_universal(1, 2, 3)
end

# ---- Top-level defs → land on Object as private by default ----

def top_secret_na(x)
  "top_secret_na: #{x.inspect}"
end

def top_secret_multi(x, y = 99)
  "top_secret_multi: #{x.inspect} #{y.inspect}"
end

def top_secret_kw(x, key: 0)
  "top_secret_kw: #{x.inspect} key=#{key}"
end

def top_secret_universal(*args)
  "top_secret_universal: #{args.inspect}"
end

def report(label, &block)
  begin
    result = block.call
    puts "#{label}: BUG — call allowed, returned #{result.inspect}"
  rescue NoMethodError => e
    puts "#{label}: OK"
  end
end

# ---- Execute phase ----

# Touch each VariantPublic* so it survives closed-world pruning and the
# survey sees the public def, forcing P4 status on every name.
puts "p4-touch-na:        #{VariantPublicNa.new.top_secret_na('hi')}"
puts "p4-touch-multi:     #{VariantPublicMulti.new.top_secret_multi('hi')}"
puts "p4-touch-kw:        #{VariantPublicKw.new.top_secret_kw('hi', key: 1)}"
puts "p4-touch-universal: #{VariantPublicUniversal.new.top_secret_universal('hi', 'there')}"

o = Other.new
report("na")                 { o.call_na(self) }
report("multi (1 arg)")      { o.call_multi_one(self) }
report("multi (2 args)")     { o.call_multi_two(self) }
report("kw")                 { o.call_kw(self) }
report("universal (splat)")  { o.call_universal(self) }
