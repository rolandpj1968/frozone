# Loads the full VM (all objects, intrinsics, etc.)
require_relative '../../lib/frozone/vm/vm'

module VmTestHelpers
  def sym(s) = s

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
  def make_method(scope, name, body: nil, required_params: [], optional_params: [],
                  rest_param: nil, post_params: [], required_kw_params: [],
                  optional_kw_params: [], kw_rest_param: nil, block_param: nil, locals: [])
    body ||= Frozone::Ast::NilLiteral::NIL
    Frozone::Vm::Method.new(
      [scope], name,
      required_params, optional_params, rest_param, post_params,
      required_kw_params, optional_kw_params, kw_rest_param,
      block_param, locals, body
    )
  end
end

RSpec.configure do |config|
  config.include VmTestHelpers
end
