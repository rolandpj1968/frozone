require 'fileutils'

# Codegen-invariant test for the visibility prologue on top-level
# private method emissions.
#
# Background: method_emitter.rb has four write_* paths
# (write_natural_arity_method, write_multi_arity_method,
# write_kw_unset_method, write_universal_method) that emit different
# C++ signature shapes for a given def, depending on the natural-args
# / kw-unset survey verdict for the name. Each of those paths must
# emit the visibility prologue
#   { auto* _cs = g_caller_self; g_caller_self = nullptr;
#     if (_cs != nullptr) raise_private_call(this, "<name>"); }
# at the top of the body for a top-level private def, OR explicit-
# other dispatch from another class will silently land in the body
# without raising NoMethodError.
#
# Why this test exists at the gen-source level instead of as a
# runtime stub: the prior `visibility_main_object_test` shipped a
# stub that called these privates from another class and expected
# the raise. But `tools/build_unified_stub.rb` wraps each unified
# stub in `module Stub_<name>` and rewrites top-level `def foo` to
# `def self.foo` — turning Object private instance methods into
# module singleton methods, which is a different dispatch path
# entirely. The unified assertion happened to pass under iile by
# coincidence and fail under stmt_expr by another coincidence,
# without either form actually verifying the property the test name
# claimed. See `feedback_test_rot.md`.
#
# This spec gens the same stub standalone (no unified wrap) and
# asserts the prologue pattern directly in the emitted Object.cpp.
# That's the property method_emitter.rb is responsible for; checking
# it at the source-string layer makes the test resilient to runtime-
# harness changes and tells us at the first failure exactly which
# write_* path regressed.

RSpec.describe 'visibility prologue codegen for top-level private defs' do
  STUB = 'bench/stubs/visibility_main_object_test.rb'.freeze
  GEN_DIR = 'cpp/gen/box/visibility_main_object_test'.freeze

  before(:all) do
    FileUtils.rm_rf(GEN_DIR)
    raise "gen failed" unless system(
      { 'FROZONE_CPP' => '1' },
      "bundle exec ruby frozone.rb --aot #{STUB}",
      out: File::NULL, err: File::NULL
    )
    @cpp = File.read("#{GEN_DIR}/visibility_main_object_test_class_Object.cpp")
  end

  # Each write_* path emits a distinctive C++ signature shape. We match
  # the body's prologue line directly under each shape's signature line
  # so a regression on one path doesn't get masked by another's prologue
  # appearing elsewhere in the same file.

  def expect_prologue_for(signature_pattern, method_name)
    # The prologue is one line immediately after the `{` of the body.
    # Match: signature line, optional whitespace, prologue line.
    pattern = /#{Regexp.escape(signature_pattern)}\s*\{\s*\n\s*\{ auto\* _cs = g_caller_self; g_caller_self = nullptr; if \(_cs != nullptr\) raise_private_call\(this, "#{method_name}"\); \}/
    expect(@cpp).to match(pattern), "expected visibility prologue for #{method_name} immediately after #{signature_pattern.inspect}"
  end

  it 'emits prologue on write_natural_arity_method (single positional arg)' do
    expect_prologue_for('BO* Object::m_top_secret_na(BO* _arg0)', 'top_secret_na')
  end

  it 'emits prologue on write_multi_arity_method (each overload of a def with optional arg)' do
    # Both the default-fill form (1 arg) and the full form (2 args).
    expect_prologue_for('BO* Object::m_top_secret_multi(BO* _arg0)',           'top_secret_multi')
    expect_prologue_for('BO* Object::m_top_secret_multi(BO* _arg0, BO* _arg1)', 'top_secret_multi')
  end

  it 'emits prologue on write_kw_unset_method (positional + named kw)' do
    expect_prologue_for('BO* Object::m_top_secret_kw(BO* _arg0, BO* _kw_key)', 'top_secret_kw')
  end

  it 'emits prologue on write_universal_method (UnivTag signature for splat)' do
    expect_prologue_for(
      'BO* Object::m_top_secret_universal(UnivTag, Array* args, Hash* kwargs, BO* block)',
      'top_secret_universal'
    )
  end

  it 'does NOT emit a prologue for the public Variant* method body' do
    # VariantPublicNa#top_secret_na is a PUBLIC def on a user class.
    # It must NOT carry the prologue (it's not an explicit-other-private
    # dispatch risk — the call site doesn't run the visibility check at
    # all for public names).
    #
    # Note: the same .cpp file also carries shadow-method copies of the
    # *other* private names (top_secret_multi/kw/universal/report) for
    # the closed-world dispatch model — those carry their own prologues
    # since they're still private overlays. We narrow this assertion to
    # *just* the body of VariantPublicNa::m_top_secret_na to avoid being
    # fooled by those.
    variant_cpp = File.read("#{GEN_DIR}/visibility_main_object_test_class_VariantPublicNa.cpp")
    body = variant_cpp.match(/BO\* VariantPublicNa::m_top_secret_na\b[^\n]*\{\n((?:.*\n)*?)^\}/)
    expect(body).to be_truthy, 'VariantPublicNa::m_top_secret_na body not found'
    expect(body[1]).not_to include('raise_private_call')
    expect(body[1]).not_to include('g_caller_self')
  end
end
