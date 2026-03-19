# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        def random_new(context, _receiver, seed)
          if frozone_nil?(seed)
            raw_seed = nil
          elsif seed.is_a?(IntegerObject)
            raw_seed = seed.raw
          elsif seed.respond_to?(:raw)
            raw_seed = seed.raw
            if raw_seed.is_a?(::Rational)
              raw_seed = raw_seed.to_i
            elsif raw_seed.is_a?(::Complex)
              if raw_seed.imaginary != 0
                raise FrozoneException.make(:RangeError, "can't convert #{raw_seed.inspect} into Integer")
              end
              raw_seed = raw_seed.real.to_i
            elsif raw_seed.respond_to?(:to_i)
              raw_seed = raw_seed.to_i
            end
          elsif seed.is_a?(ObjectObject) && seed.class_object&.name == :Complex
            imag = seed.dispatch(context, :imaginary, [], {})
            imag_raw = imag.is_a?(IntegerObject) ? imag.raw : (imag.respond_to?(:raw) ? imag.raw : 0)
            if imag_raw != 0
              raise FrozoneException.make(:RangeError, "can't convert #{seed.class_object.name}(#{imag_raw}i) into Integer")
            end
            real_obj = seed.dispatch(context, :real, [], {})
            int_obj = real_obj.dispatch(context, :to_i, [], {})
            raw_seed = int_obj.is_a?(IntegerObject) ? int_obj.raw : int_obj.raw.to_i
          elsif seed.is_a?(ObjectObject) && seed.class_object&.name == :Rational
            int_obj = seed.dispatch(context, :to_i, [], {})
            raw_seed = int_obj.is_a?(IntegerObject) ? int_obj.raw : int_obj.raw.to_i
          else
            begin
              result = seed.dispatch(context, :to_int, [], {})
              raw_seed = result.is_a?(IntegerObject) ? result.raw : result.raw.to_i
            rescue FrozoneException => e
              raise unless e.frozone_class_name == :NoMethodError
              klass = seed.respond_to?(:class_object) ? (seed.class_object&.name || seed.class) : seed.class
              raise FrozoneException.make(:TypeError, "can't convert #{klass} into Integer")
            end
          end
          RandomObject.new(raw_seed)
        end

        def random_rand(context, v, n)
          rng = v.is_a?(RandomObject) ? v.rng : Random
          if frozone_nil?(n)
            FloatObject.new(rng.rand)
          elsif n.is_a?(IntegerObject)
            IntegerObject.new(rng.rand(n.raw))
          elsif n.is_a?(FloatObject)
            FloatObject.new(rng.rand(n.raw))
          elsif n.is_a?(RangeObject)
            beg_val = n.begin_val
            end_val = n.end_val
            # If begin/end are native types, delegate to MRI rand
            if (beg_val.is_a?(IntegerObject) || beg_val.is_a?(FloatObject) ||
                frozone_nil?(beg_val)) &&
               (end_val.is_a?(IntegerObject) || end_val.is_a?(FloatObject) ||
                frozone_nil?(end_val))
              result = rng.rand(n.raw)
              result.is_a?(Integer) ? IntegerObject.new(result) : FloatObject.new(result)
            else
              # Custom object range: compute beg + rand*(end-beg)
              begin
                diff = end_val.dispatch(context, :-, [beg_val], {})
              rescue FrozoneException => e
                raise FrozoneException.make(:ArgumentError, "bad value for range") unless e.frozone_class_name == :ArgumentError
                raise
              end
              # Try integer path first (to_int)
              int_diff = begin
                diff.dispatch(context, :to_int, [], {})
              rescue FrozoneException
                nil
              end
              if int_diff&.is_a?(IntegerObject)
                size = int_diff.raw
                size -= 1 if n.exclusive? && size > 0
                rand_int = rng.rand(size + 1)
                beg_val.dispatch(context, :+, [IntegerObject.new(rand_int)], {})
              else
                # Float path
                float_diff = begin
                  diff.dispatch(context, :to_f, [], {})
                rescue FrozoneException
                  diff
                end
                diff_f = float_diff.is_a?(FloatObject) ? float_diff.raw : 1.0
                rand_f = rng.rand * diff_f
                beg_val.dispatch(context, :+, [FloatObject.new(rand_f)], {})
              end
            end
          else
            # Try to_int coercion
            begin
              result = n.dispatch(context, :to_int, [], {})
              IntegerObject.new(rng.rand(result.is_a?(IntegerObject) ? result.raw : result.raw.to_i))
            rescue FrozoneException => e
              raise unless e.frozone_class_name == :NoMethodError
              klass = n.respond_to?(:class_object) ? (n.class_object&.name || n.class) : n.class
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{klass} into Integer")
            end
          end
        end

        def random_seed(_, v)
          rng = v.is_a?(RandomObject) ? v.rng : Random
          IntegerObject.new(rng.seed)
        end

        def random_new_seed(_, _receiver)
          IntegerObject.new(Random.new_seed)
        end

        def random_bytes(_, v, n_obj)
          rng = v.is_a?(RandomObject) ? v.rng : Random
          n = n_obj.is_a?(IntegerObject) ? n_obj.raw : n_obj.raw.to_i
          StringObject.new(rng.bytes(n))
        end

        def random_urandom(_, _v, n_obj)
          n = n_obj.is_a?(IntegerObject) ? n_obj.raw : n_obj.raw.to_i
          StringObject.new(Random.urandom(n))
        end

        def random_state(_, v)
          rng = v.is_a?(RandomObject) ? v.rng : Random
          state_val = begin
            rng.send(:state)
          rescue
            rng.seed
          end
          IntegerObject.new(state_val)
        end
      end
    end
  end
end
