module RailsAdmin
  module Config
    module Fields
      module Types
        class JsonSchema < RailsAdmin::Config::Fields::Types::CodeMirror
          include JsonValueCommon

          def parse_input(params)
            super
            params[name] = nil if params.has_key?(name) && !params[name].is_a?(Hash)
          end
        end
      end
    end
  end
end
