module RailsAdmin
  module Models
    module Setup
      module FileStoreConfigAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Configuration'
            label 'File Store Config'
            weight 715

            visible do
              ::Setup::FileStoreMigration.enabled?
            end

            configure :data_type do
              read_only true
            end

            configure :file_store do
              read_only do
                ::Setup::FileStoreMigration.cannot_migrate?(bindings[:object].data_type)
              end
              help do
                if ::Setup::FileStoreMigration.unable?
                  'Your user is unable to change this attribute'
                elsif ::Setup::FileStoreMigration.migrating?(dt = bindings[:object].data_type)
                  "Data type #{dt.custom_title} is currently on a migration"
                else
                  'Required'
                end
              end
            end

            fields :data_type, :file_store, :updated_at

            show_in_dashboard false
          end
        end

      end
    end
  end
end
