module JSON
  class Schema
    class UintFormat < FormatAttribute

      class << self

        def bits(*args)
          if args.length.zero?
            @bits
          else
            unless %w(32 64).include? (@bits = args[0].to_i).to_s
              raise Exception.new("Invalid uint bit size: #{@bits}")
            end
          end
        end

        def validate(current_schema, data, fragments, processor, validator, options = {})
          return unless data.is_a?(String) || data.is_a?(Integer)

          message = nil
          if (idata = data.to_i).to_s == data.to_s
            unless 0 <= idata && idata <= 2 ** bits
              message = "The property '#{build_fragment(fragments)}' value #{data.inspect} is not in the range for uint#{bits}"
            end
          else
            message = "The property '#{build_fragment(fragments)}' value #{data.inspect} has no int format"
          end
          validation_error(processor, message, fragments, current_schema, self, options[:record_errors]) if message
        end
      end
    end

    class Uint32Format < UintFormat
      bits 32
    end

    class Uint64Format < UintFormat
      bits 64
    end
  end
end