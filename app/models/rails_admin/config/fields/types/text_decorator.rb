module RailsAdmin
  module Config
    module Fields
      module Types
        Text.class_eval do
          def parse_input(params)
            case (value = params[name])
            when Hash, Array
              params[name] = value.to_json
            else
              super
            end
          end
        end
      end
    end
  end
end
