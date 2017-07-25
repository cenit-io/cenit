module RailsAdmin
  module Config
    module Fields
      module Types
        class MongoffFileUpload < RailsAdmin::Config::Fields::Types::FileUpload

          register_instance_option :partial do
            :form_cenit_file_upload
          end

        end
      end
    end
  end
end
