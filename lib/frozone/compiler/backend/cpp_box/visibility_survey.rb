require 'set'

module Frozone
  module Compiler
    module Backend
      module CppBox
        # Pre-emission analysis: classify each reachable method def by
        # its per-class visibility, then aggregate per-name into one of
        # four patterns. See docs/box-first-visibility.md for the
        # design rationale.
        #
        #   P1 — all-public        (default and overwhelming majority)
        #   P2 — all-private       (call-site syntactic check)
        #   P3 — all-protected     (call-site kind_of? check)
        #   P4 — mixed across classes (only case needing universal-slot
        #                              caller_self thread)
        #
        # The per-(class, name) table is what call-site codegen consults
        # to pick the right check. The per-name patterns drive whether
        # the universal-slot ABI needs the 4th `caller_self` arg at all
        # (only if any P4 names exist).
        module VisibilitySurvey
          Result = Struct.new(:per_class, :per_name, :p3_names, :p4_names, :p2_names, :counts) do
            def to_s
              "VisibilitySurvey(P1=#{counts[:p1]}, P2=#{counts[:p2]}, P3=#{counts[:p3]}, P4=#{counts[:p4]})"
            end
          end

          # Walk every reachable class's methods_table — both the
          # instance-method table and the singleton (eigenclass)
          # methods table — and extract visibility per (class, name).
          # Aggregate per-name into one of the four patterns.
          #
          # `all_classes` is the hash returned by emitter#collect_all_classes
          # (flat_name → ModuleObject/ClassObject). Each class's eigenclass
          # is reached via singleton_class — its methods_table holds class
          # methods (`def self.foo`, post-hoc `private_class_method :foo`
          # declarations, etc.).
          #
          # Instance and class methods sharing a name are tracked under
          # the SAME name key: e.g. `Kernel#open` (private instance) and
          # `File.open` (public class) together classify `open` as P4
          # mixed, which is the correct call-site treatment (universal
          # slot decides at runtime based on receiver type).
          def self.compute(all_classes)
            per_class = {}            # flat_class_name => { method_name => :public|:private|:protected }
            per_name_vises = {}       # method_name => Set of visibilities seen

            visit = lambda do |flat, cls|
              vis_map = {}
              (cls.methods_table || {}).each do |name, m|
                # Skip undef-sentinels (raw Symbols) and anything without a
                # visibility (defensive — Method and VisibilityOverride both
                # have it; nothing else should land in methods_table).
                next unless m.respond_to?(:visibility)
                vis = m.visibility
                next if vis.nil?
                vis_map[name] = vis
                (per_name_vises[name] ||= Set.new) << vis
              end
              per_class[flat] = vis_map unless vis_map.empty?
            end

            all_classes.each do |flat, cls|
              visit.call(flat, cls)
              # Eigenclass (class-method table). Lazy: singleton_class
              # auto-creates on first read. We materialise it here only
              # for classes that have one, which is virtually all of
              # them in practice. The eigenclass's flat name uses the
              # centralised EIG_SUFFIX for uniqueness in per_class.
              if cls.respond_to?(:singleton_class) && (ec = cls.singleton_class)
                visit.call(:"#{flat}#{Frozone::Compiler::Reachability::EIG_SUFFIX}", ec)
              end
            end

            per_name = {}
            p2_names = []
            p3_names = []
            p4_names = []
            counts = { p1: 0, p2: 0, p3: 0, p4: 0 }

            per_name_vises.each do |name, vises|
              pattern =
                if vises == Set[:public]
                  counts[:p1] += 1
                  :p1
                elsif vises == Set[:private]
                  counts[:p2] += 1
                  p2_names << name
                  :p2
                elsif vises == Set[:protected]
                  counts[:p3] += 1
                  p3_names << name
                  :p3
                else
                  counts[:p4] += 1
                  p4_names << name
                  :p4
                end
              per_name[name] = pattern
            end

            Result.new(per_class, per_name, p3_names, p4_names, p2_names, counts)
          end

          # Format the survey for stderr — pattern counts plus the
          # interesting names (P3 + P4 enumerated since they're
          # expected to be small; P2 just counted).
          def self.format_summary(result)
            lines = []
            lines << "[box-first] visibility: P1=#{result.counts[:p1]} public, " \
                     "P2=#{result.counts[:p2]} private, " \
                     "P3=#{result.counts[:p3]} protected, " \
                     "P4=#{result.counts[:p4]} mixed"
            unless result.p3_names.empty?
              lines << "[box-first] visibility P3 (protected) names: #{result.p3_names.sort.join(', ')}"
            end
            unless result.p4_names.empty?
              lines << "[box-first] visibility P4 (mixed) names: #{result.p4_names.sort.join(', ')}"
            end
            if (filt = ENV['FROZONE_VISIBILITY_FILTER'])
              names = filt.split(',').map { |n| n.strip.to_sym }
              names.each do |name|
                pattern = result.per_name[name]
                cw = result.per_class.each_with_object([]) { |(c, vm), a| a << [c, vm[name]] if vm.key?(name) }
                lines << "  #{name.to_s.ljust(20)} pattern=#{pattern.inspect.ljust(8)} #{cw.inspect}"
              end
            end
            if ENV['FROZONE_VISIBILITY_DETAIL'] == '1'
              lines << "[box-first] visibility P4 per-class detail:"
              result.p4_names.sort.each do |name|
                with = result.per_class.each_with_object([]) { |(c, vm), a| a << [c, vm[name]] if vm.key?(name) }
                by_vis = with.group_by { |_, v| v }
                breakdown = by_vis.map { |v, l| "#{v}=#{l.size}" }.sort.join(' ')
                lines << "  #{name.to_s.ljust(28)} #{breakdown}"
                by_vis.each do |vis, list|
                  sample = list.take(4).map { |c, _| c }.join(', ')
                  more = list.size > 4 ? ", +#{list.size - 4}" : ''
                  lines << "    #{vis}: #{sample}#{more}"
                end
              end
            end
            lines.join("\n")
          end
        end
      end
    end
  end
end
