module RailsAdmin
  module Config
    module Fields
      module Types
        class JsonValue < RailsAdmin::Config::Fields::Types::Code
          include JsonValueCommon
        end
      end
    end
  end
end
