module RailsAdmin
  module Config
    module Fields
      module Types
        class JsonValue < RailsAdmin::Config::Fields::Types::Text
          include JsonValueCommon
        end
      end
    end
  end
end
