module RailsAdmin
  module Config
    module Fields
      module Types
        class TimeSpan < RailsAdmin::Config::Fields::Types::Text

          register_instance_option :negative_pretty_value do
            '-'
          end

          register_instance_option :metric do
            :s
          end

          register_instance_option :pretty_value do
            if (v = value) < 0
              negative_pretty_value
            else
              str = ''
              h = {
                ms: 1000,
                s: 1000,
                m: 60,
                h: 60,
                d: 24
              }
              current_metric = metric
              h.keys.each do|m|
                h.delete(m)
                break if m == current_metric
              end
              h.each do |m, scale|
                if (scaled_v = v / scale) > 0
                  str = "#{v % scale}#{current_metric} #{str}"
                  v = scaled_v
                  current_metric = m
                else
                  str = "#{v}#{current_metric} #{str}"
                  break
                end
              end
              str
            end
          end

        end
      end
    end
  end
end
