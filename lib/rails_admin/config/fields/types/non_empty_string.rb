module RailsAdmin
  module Config
    module Fields
      module Types
        class NonEmptyString < RailsAdmin::Config::Fields::Types::String

          def parse_input(params)
            if params[name].to_s.empty?
              params[name] = nil
            end
          end
        end
      end
    end
  end
end