module RailsAdmin
  module Config
    module Fields
      module Types
        class MongoffFileUpload < RailsAdmin::Config::Fields::Types::FileUpload

          def resource_url
            '' #TODO Complete when extending file controller
          end
        end
      end
    end
  end
end
