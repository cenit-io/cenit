module RailsAdmin
  module Config
    module Fields
      module Types
        class NonEmptyText < RailsAdmin::Config::Fields::Types::Text

          def parse_input(params)
            puts "<<< #{name} >>>"
            if params[name].to_s.empty?
              params[name] = nil
            end
            puts params.to_json
          end
        end
      end
    end
  end
end