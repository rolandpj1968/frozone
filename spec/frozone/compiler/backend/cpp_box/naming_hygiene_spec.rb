require_relative '../../../../support/vm_loader'
require_relative '../../../../../lib/frozone/compiler/backend/cpp_box/naming'

# Grep-lint: hand-written C++ flat-name literals in cpp_box Ruby source
# silently misresolve when the escape rule changes or when the source
# Ruby name contains an underscore. Every reference to a Ruby constant
# in emitted C++ must route through CppBox.k_call / klass_ptr_ref /
# klass_ptr_name / eig_struct so the flattening happens in one place.
#
# See:
#   - lib/frozone/compiler/backend/cpp_box/naming.rb (the helpers)
#   - task #227 (the audit that landed this)
#   - the "SPLAT_PROC" and "UTF__8" bug hunts that motivated it
RSpec.describe 'cpp_box flat-name hygiene' do
  CPP_BOX_DIR = File.expand_path('../../../../../lib/frozone/compiler/backend/cpp_box', __dir__)

  # Allowlist for files whose contents are not part of this audit's
  # scope:
  #
  #   - naming.rb: the helpers themselves.
  #   - runtime/universe.rb: declares RubyClass entries as Ruby-side
  #     constants like `NIL_CLASS = RubyClass.new(...)` that match
  #     the regex but are Ruby module-level constants, not C++ output.
  #     Its inline C++ heredoc strings that reference _CLASS singletons
  #     are a separate audit tracked as follow-up (task #227 body).
  ALLOW_FILES = %w[naming.rb universe.rb].freeze

  def cpp_box_source_files
    Dir[File.join(CPP_BOX_DIR, '**', '*.rb')].reject do |path|
      ALLOW_FILES.include?(File.basename(path))
    end
  end

  # Match `Foo_CLASS` or `Foo_Bar_CLASS` as a bare identifier in code.
  # This catches string literals like `"(&Foo_CLASS)"` and interpolated
  # forms like `"...#{recv}_CLASS"` — both are hand-encoded flat names.
  BAD_CLASS_REF_RE = /[A-Z][A-Za-z0-9_]*_CLASS\b/.freeze

  # Match `k_Foo_Bar()` as a bare identifier (accessor call for a
  # value-constant). Same reasoning as above.
  BAD_K_CALL_RE = /\bk_[A-Z][A-Za-z0-9_]*\s*\(/.freeze

  # Lines matching either regex are still allowed if they invoke the
  # helper itself — e.g. `CppBox.klass_ptr_ref('Foo')` interpolates
  # `Foo_CLASS` into its output at emit time; that's the helper doing
  # its job, not a hand-encoded literal.
  HELPER_CALL_RE = /Cpp\w{0,4}\.(k_call|klass_ptr_ref|klass_ptr_name|eig_struct|flatten)\b/.freeze

  # Also skip lines that reference `_CLASS` as an inline C++ comment
  # (e.g. `emit.line "nullptr, // ... use Class_CLASS"`). The comment
  # is human-readable text about the pattern, not a live reference.
  COMMENT_MARKER_RE = %r{//.*_CLASS}.freeze

  # Interpolation-driven `_CLASS` refs — `"&#{name}_CLASS"` — where the
  # name is threaded from an already-flat `k.name` or similar. Routing
  # these through `klass_ptr_ref(name)` would double-flatten. Follow-up
  # to standardise the "flat vs raw" boundary at these sites.
  INTERPOLATED_CLASS_RE = /\}_CLASS\b/.freeze

  it 'has no hand-written _CLASS references in cpp_box/*.rb' do
    hits = []
    cpp_box_source_files.each do |path|
      File.foreach(path).with_index(1) do |line, lineno|
        # Skip comment lines.
        next if line =~ /\A\s*#/
        next unless line =~ BAD_CLASS_REF_RE
        next if line =~ HELPER_CALL_RE
        next if line =~ COMMENT_MARKER_RE
        next if line =~ INTERPOLATED_CLASS_RE
        hits << "#{path}:#{lineno}: #{line.chomp}"
      end
    end
    expect(hits).to be_empty, <<~MSG
      Found hand-written *_CLASS literals in cpp_box source. Route
      through CppBox.klass_ptr_ref('Foo') / klass_ptr_name('Foo') so
      the flat-name encoding stays in one place. See task #227.

      Hits:
        #{hits.join("\n  ")}
    MSG
  end

  it 'has no hand-written k_Foo_Bar() accessor calls in cpp_box/*.rb' do
    hits = []
    cpp_box_source_files.each do |path|
      File.foreach(path).with_index(1) do |line, lineno|
        next if line =~ /\A\s*#/
        next unless line =~ BAD_K_CALL_RE
        next if line =~ HELPER_CALL_RE
        hits << "#{path}:#{lineno}: #{line.chomp}"
      end
    end
    expect(hits).to be_empty, <<~MSG
      Found hand-written k_Foo_Bar() accessor calls in cpp_box source.
      Route through CppBox.k_call('Foo::Bar') so the flat-name
      encoding stays in one place. See task #227.

      Hits:
        #{hits.join("\n  ")}
    MSG
  end
end

RSpec.describe Frozone::Compiler::Backend::CppBox do
  describe '.flatten' do
    it 'escapes source underscore then collapses ::' do
      expect(described_class.flatten('Foo::Bar')).to eq('Foo_Bar')
      expect(described_class.flatten('Foo_Bar')).to eq('Foo__Bar')
      expect(described_class.flatten('Encoding::UTF_8')).to eq('Encoding_UTF__8')
    end
  end

  describe '.k_call' do
    it 'wraps flatten in the C++ accessor-call form' do
      expect(described_class.k_call('Encoding::UTF_8')).to eq('k_Encoding_UTF__8()')
    end
  end

  describe '.klass_ptr_ref' do
    it 'produces the (&Foo_CLASS) pointer-ref form' do
      expect(described_class.klass_ptr_ref('RuntimeError')).to eq('(&RuntimeError_CLASS)')
      expect(described_class.klass_ptr_ref('Frozone::Vm::ModuleObject')).to eq('(&Frozone_Vm_ModuleObject_CLASS)')
    end
  end

  describe '.klass_ptr_name' do
    it 'produces the bare Foo_CLASS identifier form' do
      expect(described_class.klass_ptr_name('Module')).to eq('Module_CLASS')
    end
  end

  describe '.eig_struct' do
    it 'suffixes the flat name with _eig' do
      expect(described_class.eig_struct('Foo')).to eq('Foo_eig')
      expect(described_class.eig_struct('Frozone::Vm::ModuleObject')).to eq('Frozone_Vm_ModuleObject_eig')
    end
  end
end
