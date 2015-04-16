module RailsAdmin
  module Config
    module Fields
      module Types
        class JsonSchema < RailsAdmin::Config::Fields::Types::CodeMirror

          register_instance_option :formatted_value do
            (JSON.pretty_generate(value) rescue nil) || value.to_s
          end

          def parse_input(params)
            return unless (value = params[name]).is_a?(::String)
            params[name] =
              if value.blank?
                nil
              elsif v = JSON.parse(value) rescue nil
                v
              elsif value == 'true'
                true
              elsif value == 'false'
                false
              elsif (v = value.to_i).to_s == value
                v
              elsif (v = value.to_f).to_s == value
                v
              else
                value
              end
          end
        end
      end
    end
  end
end
