require_relative '../../../../support/vm_loader'
require_relative '../../../../../lib/frozone/compiler/backend/cpp_box/cpp'

# Form-switch helper tests — each of the helpers that emit IILE-or-
# stmt_expr based on `Cpp.block_expr_form` must produce the right
# shape in both forms. The actual env-var resolution is in
# `block_expr_form`; here we stub that to force each form per test.
#
# These are string-level checks against the emitted C++ skeleton.
# Runtime parity (the actual programs producing the same output in
# both forms) is covered separately in block_expr_form_runtime_spec.

C = Frozone::Compiler::Backend::CppBox::Cpp unless defined?(C)

RSpec.describe 'Cpp form-switch helpers' do
  def force_form(form)
    allow(C).to receive(:block_expr_form).and_return(form)
  end

  describe '.block_expr' do
    context 'iile form' do
      before { force_form(:iile) }

      it 'wraps stmts + value in a self-invoking lambda' do
        out = C.block_expr(['auto* _x = recv;'], '_x->next()')
        expect(out).to eq('([&]() -> BO* { auto* _x = recv; return _x->next(); }())')
      end

      it 'allows custom return type' do
        out = C.block_expr(['Hash* _h = new Hash();'], '_h', type: 'Hash*')
        expect(out).to eq('([&]() -> Hash* { Hash* _h = new Hash(); return _h; }())')
      end

      it 'handles empty stmts' do
        out = C.block_expr([], 'nil_instance()')
        expect(out).to eq('([&]() -> BO* { return nil_instance(); }())')
      end

      it 'joins multiple stmts with single spaces' do
        out = C.block_expr(['auto* _r = recv;', 'auto* _i = idx;'], '_r->aref(_i)')
        expect(out).to eq('([&]() -> BO* { auto* _r = recv; auto* _i = idx; return _r->aref(_i); }())')
      end
    end

    context 'stmt_expr form' do
      before { force_form(:stmt_expr) }

      it 'wraps stmts + value in a gcc statement expression' do
        out = C.block_expr(['auto* _x = recv;'], '_x->next()')
        expect(out).to eq('({ auto* _x = recv; _x->next(); })')
      end

      it 'ignores the `type:` kwarg (stmt-expr infers from last)' do
        out = C.block_expr(['Hash* _h = new Hash();'], '_h', type: 'Hash*')
        expect(out).to eq('({ Hash* _h = new Hash(); _h; })')
      end

      it 'handles empty stmts' do
        out = C.block_expr([], 'nil_instance()')
        expect(out).to eq('({ nil_instance(); })')
      end
    end
  end

  describe '.throw_expr' do
    context 'iile form' do
      before { force_form(:iile) }

      it 'wraps a throw stmt in a typed lambda (no return)' do
        out = C.throw_expr(['throw foo;'])
        expect(out).to eq('([&]() -> BO* { throw foo; }())')
      end

      it 'allows multiple stmts before the throw' do
        out = C.throw_expr(['auto* _r = recv;', 'raise_private_call(_r, "name");'])
        expect(out).to eq('([&]() -> BO* { auto* _r = recv; raise_private_call(_r, "name"); }())')
      end
    end

    context 'stmt_expr form' do
      before { force_form(:stmt_expr) }

      it 'wraps in stmt-expr and appends nil_instance() type sentinel' do
        # The throw is `void`; stmt-expr type is its last expression.
        # The trailing `nil_instance();` gives the construct a `BO*` type
        # and is unreachable past the throw.
        out = C.throw_expr(['throw foo;'])
        expect(out).to eq('({ throw foo; nil_instance(); })')
      end

      it 'allows multiple stmts before the throw' do
        out = C.throw_expr(['auto* _r = recv;', 'raise_private_call(_r, "name");'])
        expect(out).to eq('({ auto* _r = recv; raise_private_call(_r, "name"); nil_instance(); })')
      end
    end
  end

  describe '.try_catch_expr' do
    context 'iile form' do
      before { force_form(:iile) }

      it 'wraps try/catch with return-from-lambda for both arms' do
        out = C.try_catch_expr('do_call()', 'BreakException& e_', 'e_.value')
        expect(out).to eq('([&]() -> BO* { try { return do_call(); } catch (BreakException& e_) { return e_.value; } }())'
        )
      end
    end

    context 'stmt_expr form' do
      before { force_form(:stmt_expr) }

      it 'wraps try/catch with a result temp inside stmt-expr' do
        out = C.try_catch_expr('do_call()', 'BreakException& e_', 'e_.value')
        expect(out).to eq('({ BO* _r; try { _r = do_call(); } catch (BreakException& e_) { _r = e_.value; } _r; })')
      end
    end
  end

  describe '.staged_block_expr' do
    let(:phases) {
      [
        { stmts: ['auto* _r = recv;', 'auto* _c = _r->aref(k);'],
          early_return: { cond: 'truthy(_c)', value: '_c' } },
        { stmts: ['auto* _n = compute();', '_r->aset(k, _n);'],
          value: '_n' }
      ]
    }

    context 'iile form' do
      before { force_form(:iile) }

      it 'emits a linear if/return chain ending in a final return' do
        out = C.staged_block_expr(phases)
        expect(out).to eq(
          '([&]() -> BO* { auto* _r = recv; auto* _c = _r->aref(k); ' \
          'if (truthy(_c)) return _c; ' \
          'auto* _n = compute(); _r->aset(k, _n); return _n; }())'
        )
      end
    end

    context 'stmt_expr form' do
      before { force_form(:stmt_expr) }

      it 'emits a nested-ternary chain — side effects only fire in the false arm' do
        out = C.staged_block_expr(phases)
        # outer stmt-expr declares stage-0 setup, then ternary
        # whose false arm is a nested stmt-expr with stage-1's stmts + value.
        expect(out).to eq(
          '({ auto* _r = recv; auto* _c = _r->aref(k); ' \
          'truthy(_c) ? static_cast<BO*>(_c) : ' \
          'static_cast<BO*>(({ auto* _n = compute(); _r->aset(k, _n); _n; })); })'
        )
      end

      it 'three-phase chain nests two ternaries' do
        three = [
          { stmts: ['char _buf[32];', 'double _v = raw;'],
            early_return: { cond: 'std::isnan(_v)', value: 'new String("NaN", 3)' } },
          { stmts: [],
            early_return: { cond: 'std::isinf(_v)', value: 'new String("Inf", 3)' } },
          { stmts: ['int _n = std::snprintf(_buf, 32, "%g", _v);'],
            value: 'new String(_buf, _n)' }
        ]
        out = C.staged_block_expr(three)
        expect(out).to eq(
          '({ char _buf[32]; double _v = raw; ' \
          'std::isnan(_v) ? static_cast<BO*>(new String("NaN", 3)) : ' \
          'static_cast<BO*>(({ std::isinf(_v) ? static_cast<BO*>(new String("Inf", 3)) : ' \
          'static_cast<BO*>(({ int _n = std::snprintf(_buf, 32, "%g", _v); new String(_buf, _n); })); })); })'
        )
      end
    end
  end
end
