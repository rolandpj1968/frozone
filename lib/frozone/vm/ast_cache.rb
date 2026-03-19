require 'digest'
require 'fileutils'
require 'shellwords'

module Frozone
  module Vm
    module AstCache
      ParseResult = Struct.new(:ast, :top_level_locals, :prism_always_warnings, :prism_verbose_warnings)

      class << self
        def enabled?
          @enabled
        end

        def disable!
          @enabled = false
        end

        def git_sha
          @git_sha ||= begin
            dir = File.expand_path('../../..', __dir__).shellescape
            sha = `git -C #{dir} rev-parse HEAD 2>/dev/null`.strip
            return "unknown" if sha.empty?
            # Disable cache entirely on a dirty working tree: any AST change
            # mid-session would silently serve stale entries under the same key.
            dirty = !`git -C #{dir} status --porcelain 2>/dev/null`.strip.empty?
            if dirty
              @enabled = false
              return "dirty"
            end
            sha
          rescue StandardError
            "unknown"
          end
        end

        def cache_base_dir
          @cache_base_dir ||= File.expand_path("~/.frozone/ast")
        end

        def cache_dir(parser_name)
          dir = File.join(cache_base_dir, git_sha, parser_name.to_s)
          FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
          dir
        end

        def cleanup_old_versions
          return unless Dir.exist?(cache_base_dir)

          current = git_sha
          Dir.each_child(cache_base_dir) do |entry|
            next if entry == current

            old_dir = File.join(cache_base_dir, entry)
            FileUtils.rm_rf(old_dir) if File.directory?(old_dir)
          end
        rescue StandardError
          # Non-fatal: ignore cleanup errors
        end

        def cache_path(source, parser_name)
          sha256 = Digest::SHA256.hexdigest(source)
          File.join(cache_dir(parser_name), "#{sha256}.ast")
        end

        # Level-1: in-process memory cache keyed by [filepath, mtime, parser_name].
        # Avoids SHA256 and disk I/O for files loaded repeatedly within one process
        # (e.g. load_core called for each new Vm in the test suite).
        def fetch_file(filepath, parser_name)
          return nil unless @enabled

          mtime = File.mtime(filepath).to_f
          @memory_cache[[filepath, mtime, parser_name]]
        rescue StandardError
          nil
        end

        def store_file(filepath, parser_name, result)
          return unless @enabled

          mtime = File.mtime(filepath).to_f
          @memory_cache[[filepath, mtime, parser_name]] = result
        rescue StandardError
          nil
        end

        # Level-2: on-disk content-addressed cache keyed by SHA256(source).
        def fetch(source, parser_name)
          return nil unless @enabled

          path = cache_path(source, parser_name)
          return nil unless File.exist?(path)

          data = File.binread(path)
          Marshal.load(data)
        rescue StandardError
          nil
        end

        def store(source, parser_name, result)
          return unless @enabled

          path = cache_path(source, parser_name)
          File.binwrite(path, Marshal.dump(result))
        rescue StandardError
          # Non-fatal: ignore write errors
        end
      end

      @enabled = true
      @memory_cache = {}
    end
  end
end
