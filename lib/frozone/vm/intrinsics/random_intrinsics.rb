# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        def random_new_seed(_, _receiver) = n2f_int(Random.new_seed)
        def random_seed(_, v) = (rng = v.is_a?(RandomObject) ? v.rng : Random; n2f_int(rng.seed))
        def random_urandom(_, _v, n_obj) = (n = fint?(n_obj) ? n_obj.raw : n_obj.raw.to_i; n2f_str(Random.urandom(n)))

        def random_new(context, _receiver, seed)
          if fnil?(seed)
            raw_seed = nil
          elsif fint?(seed)
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
            imag_raw = fint?(imag) ? imag.raw : (fobj?(imag) ? imag.raw : 0)
            if imag_raw != 0
              raise FrozoneException.make(:RangeError, "can't convert #{seed.class_object.name}(#{imag_raw}i) into Integer")
            end
            real_obj = seed.dispatch(context, :real, [], {})
            int_obj = real_obj.dispatch(context, :to_i, [], {})
            raw_seed = fint?(int_obj) ? int_obj.raw : int_obj.raw.to_i
          elsif seed.is_a?(ObjectObject) && seed.class_object&.name == :Rational
            int_obj = seed.dispatch(context, :to_i, [], {})
            raw_seed = fint?(int_obj) ? int_obj.raw : int_obj.raw.to_i
          else
            begin
              result = seed.dispatch(context, :to_int, [], {})
              raw_seed = fint?(result) ? result.raw : result.raw.to_i
            rescue FrozoneException => e
              raise unless e.frozone_class_name == :NoMethodError
              klass = frozone_class_name(seed)
              raise FrozoneException.make(:TypeError, "can't convert #{klass} into Integer")
            end
          end
          RandomObject.new(raw_seed)
        end

        def random_rand(context, v, n)
          rng = v.is_a?(RandomObject) ? v.rng : Random
          if fnil?(n)
            n2f_float(rng.rand)
          elsif fint?(n)
            n2f_int(rng.rand(n.raw))
          elsif ffloat?(n)
            n2f_float(rng.rand(n.raw))
          elsif n.is_a?(RangeObject)
            beg_val = n.begin_val
            end_val = n.end_val
            # If begin/end are native types, delegate to MRI rand
            if (fint?(beg_val) || ffloat?(beg_val) ||
                fnil?(beg_val)) &&
               (fint?(end_val) || ffloat?(end_val) ||
                fnil?(end_val))
              result = rng.rand(n.raw)
              result.is_a?(Integer) ? n2f_int(result) : n2f_float(result)
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
              if int_diff && fint?(int_diff)
                size = int_diff.raw
                size -= 1 if n.exclusive? && size > 0
                rand_int = rng.rand(size + 1)
                beg_val.dispatch(context, :+, [n2f_int(rand_int)], {})
              else
                # Float path
                float_diff = begin
                  diff.dispatch(context, :to_f, [], {})
                rescue FrozoneException
                  diff
                end
                diff_f = ffloat?(float_diff) ? float_diff.raw : 1.0
                rand_f = rng.rand * diff_f
                beg_val.dispatch(context, :+, [n2f_float(rand_f)], {})
              end
            end
          else
            # Try to_int coercion
            begin
              result = n.dispatch(context, :to_int, [], {})
              n2f_int(rng.rand(fint?(result) ? result.raw : result.raw.to_i))
            rescue FrozoneException => e
              raise unless e.frozone_class_name == :NoMethodError
              klass = frozone_class_name(n)
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{klass} into Integer")
            end
          end
        end

        def random_bytes(_, v, n_obj)
          rng = v.is_a?(RandomObject) ? v.rng : Random
          n = fint?(n_obj) ? n_obj.raw : n_obj.raw.to_i
          n2f_str(rng.bytes(n))
        end

        def random_state(_, v)
          rng = v.is_a?(RandomObject) ? v.rng : Random
          state_val = begin
            rng.send(:state)
          rescue
            rng.seed
          end
          n2f_int(state_val)
        end

        def random_marshal_load(_, v, data_obj)
          # data_obj is a Frozone ArrayObject containing [state_bignum, position, seed]
          # Convert each element to a native Ruby integer
          raw_data = if data_obj.is_a?(ArrayObject)
            data_obj.raw.map { |el| fint?(el) ? el.raw : (el.respond_to?(:raw) ? el.raw.to_i : el.to_i) }
          else
            []
          end
          # Reconstruct MRI Random via marshal_load
          new_rng = Random.allocate
          new_rng.__send__(:marshal_load, raw_data)
          if v.is_a?(RandomObject)
            v.rng = new_rng
          else
            v.set_ivar(:@rng, new_rng)
          end
          nil
        end
      end
    end
  end
end
