module RailsAdmin
  module Config
    module Fields
      module Types
        class JsonSchema < RailsAdmin::Config::Fields::Types::CodeMirror

          register_instance_option :formatted_value do
            if value.is_a?(::String)
              "\"#{value}\""
            else
              (JSON.pretty_generate(value) rescue nil) || value
            end
          end

          def parse_input(params)
            return unless (value = params[name]).is_a?(::String)
            params[name] =
              if value.blank?
                nil
              elsif value.start_with?('"') && value.end_with?('"')
                value[1..value.length - 2]
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
