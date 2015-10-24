module RailsAdmin
  module Config
    module Fields
      module Types
        module JsonValueCommon
          extend ActiveSupport::Concern

          included do
            register_instance_option :formatted_value do
              if value.is_a?(::String)
                "\"#{value}\""
              else
                (JSON.pretty_generate(value) rescue nil) || value
              end
            end
          end

          def parse_input(params)
            params[name] = Cenit::Utility.json_value_of(params[name]) if params.has_key?(name)
          end
        end
      end
    end
  end
end