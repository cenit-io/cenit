module RailsAdmin
  module Config
    module Fields
      module Types
        class JsonSchema < RailsAdmin::Config::Fields::Types::Code
          include JsonValueCommon

          def parse_input(params)
            super
            params[name] = nil if params.has_key?(name) &&
              !(params[name].is_a?(ActionController::Parameters) || params[name].is_a?(::Hash) || params[name].is_a?(::String))
          end
        end
      end
    end
  end
end
