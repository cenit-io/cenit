module RailsAdmin
  module Config
    module Fields
      module Types
        class JsonSchema < RailsAdmin::Config::Fields::Types::CodeMirror
          include JsonValueCommon
        end
      end
    end
  end
end
