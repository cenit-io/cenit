module RailsAdmin
  module Config
    module Fields
      module Types
        class TimeSpan < RailsAdmin::Config::Fields::Types::Text

          register_instance_option :pretty_value do
            v = (value * 1000000).to_i
            metric = :ns
            done = false
            {
              ms: 1000,
              s: 1000,
              m: 60,
              h: 60,
              d: 24
            }.each do |non, scale|
              next if done
              if (scaled_v = v / scale) > 0
                v = scaled_v
                metric = non
              else
                done = true
              end
            end
            "#{v}#{metric}"
          end

        end
      end
    end
  end
end
