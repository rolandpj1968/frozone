# Loads the full VM (all objects, intrinsics, etc.)
require_relative '../../lib/frozone/vm/vm'

module VmTestHelpers
  def sym(s) = Frozone::Vm::SymbolObject.from(s)

  # Build a minimal evaluation context with one frame and the given scope chain.
  # Defaults to [OBJECT_CLASS] as the scope chain.
  def make_context(the_self: nil, locals: [], scopes: nil)
    scopes ||= [Frozone::Vm::Core::OBJECT_CLASS]
    the_self ||= Frozone::Vm::ObjectObject.new(Frozone::Vm::Core::OBJECT_CLASS)
    ctx = Frozone::Vm::Context.new
    frame = Frozone::Vm::Frame.new(the_self, locals, scopes)
    ctx.push_frame(frame)
    scopes.each { |s| ctx.push_scope(s) }
    ctx
  end

  # Build a minimal Method object. Body defaults to NilLiteral (returns NIL).
  # name and all Symbol param names are automatically converted to SymbolObjects.
  def make_method(scope, name, body: nil, required_params: [], optional_params: [],
                  rest_param: nil, post_params: [], required_kw_params: [],
                  optional_kw_params: [], kw_rest_param: nil, locals: [])
    body ||= Frozone::Ast::NilLiteral::NIL
    to_sym = ->(s) { s.is_a?(Symbol) ? sym(s) : s }
    Frozone::Vm::Method.new(
      [scope], to_sym.(name),
      required_params.map(&to_sym),
      optional_params.map { |s, n| [to_sym.(s), n] },
      rest_param && to_sym.(rest_param),
      post_params.map(&to_sym),
      required_kw_params.map(&to_sym),
      optional_kw_params.map { |s, n| [to_sym.(s), n] },
      kw_rest_param && to_sym.(kw_rest_param),
      locals.map(&to_sym),
      body
    )
  end
end

RSpec.configure do |config|
  config.include VmTestHelpers
end
