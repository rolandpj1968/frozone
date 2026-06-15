require 'etc'
require 'tmpdir'

# Runtime parity test for `FROZONE_BOX_BLOCK_EXPR_FORM`. Builds
# bench/stubs/iile_parity.rb under both forms (iile, stmt_expr) and
# asserts the stdout is byte-identical. The stub exercises every
# helper that emits IILE-or-stmt_expr-conditionally:
#   block_expr / throw_expr / try_catch_expr / staged_block_expr
#   body_as_lambda_call / from_if_as_stmt_expr / from_rescue_stmt_expr
#
# Each form requires a full AOT gen + g++ build (~2 min cold), so we
# tag the spec :slow and skip it unless `BOX_FORM_PARITY=1`. Run
# explicitly with:
#   BOX_FORM_PARITY=1 bundle exec rspec spec/.../block_expr_form_runtime_spec.rb
# CI should set BOX_FORM_PARITY=1 in the nightly job.

if ENV['BOX_FORM_PARITY'] == '1'
  RSpec.describe 'bench/stubs/iile_parity.rb form parity' do
    ONIGMO_INCLUDE = File.expand_path('../../../../../../vendor/Onigmo', __FILE__).freeze
    ONIGMO_LIB     = File.expand_path('../../../../../../vendor/Onigmo/.libs/libonigmo.a', __FILE__).freeze
    STUB           = 'bench/stubs/iile_parity.rb'.freeze

    def self.build_and_run(form)
      dir = "cpp/gen/box/iile_parity_#{form}"
      FileUtils.rm_rf(dir)
      env = { 'FROZONE_CPP' => '1', 'FROZONE_BOX_BLOCK_EXPR_FORM' => form }
      raise "gen failed (#{form})" unless system(env, "bundle exec ruby frozone.rb --aot #{STUB}", out: File::NULL, err: File::NULL)
      FileUtils.mv('cpp/gen/box/iile_parity', dir)
      cpp_files = Dir.glob("#{dir}/*.cpp").sort
      runtime_cpps = Dir["cpp/runtime/intrinsics/*_intrinsics.cpp"].sort
      q = Queue.new
      cpp_files.each { |f| q << [f, f.sub(/\.cpp\z/, '.o')] }
      runtime_cpps.each { |f| q << [f, "#{dir}/iile_parity_intrinsic_#{File.basename(f, '_intrinsics.cpp')}.o"] }
      errs = []; o = []; m = Mutex.new
      Array.new(Etc.nprocessors) { Thread.new {
        loop {
          cpp, oo = q.pop(true) rescue break
          ok = system("g++ -O2 -flto -std=c++20 -I #{dir} -I #{ONIGMO_INCLUDE} -c #{cpp} -o #{oo} 2>/dev/null")
          m.synchronize { ok ? o << oo : errs << cpp }
        }
      } }.each(&:join)
      raise "compile errors (#{form}): #{errs.size}" if errs.any?
      bin = "#{dir}/iile_parity_bin"
      raise "link failed (#{form})" unless system("g++ -O2 -flto -std=c++20 #{o.sort.join(' ')} #{ONIGMO_LIB} -lgc -o #{bin} 2>/dev/null")
      `#{bin}`
    end

    # Memoize — both forms are expensive to build (~2 min each).
    before(:all) do
      @iile_out      = self.class.build_and_run('iile')
      @stmt_expr_out = self.class.build_and_run('stmt_expr')
    end

    it 'iile form produces the expected ALL OK sentinel' do
      expect(@iile_out).to include('ALL OK')
    end

    it 'stmt_expr form produces the expected ALL OK sentinel' do
      expect(@stmt_expr_out).to include('ALL OK')
    end

    it 'iile and stmt_expr forms produce byte-identical output' do
      # If this fails, write both transcripts out for inspection.
      if @iile_out != @stmt_expr_out
        File.write('/tmp/iile_parity_iile.out', @iile_out)
        File.write('/tmp/iile_parity_stmt_expr.out', @stmt_expr_out)
      end
      expect(@stmt_expr_out).to eq(@iile_out)
    end
  end
end
