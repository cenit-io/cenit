module RailsAdmin
  module Models
    module Setup
      module PrawnTemplateAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Transforms'
            label 'Prawn Template'
            weight 410
            object_label_method { :custom_title }

            hide_on_navigation

            configure :code_warnings, :code_warnings

            configure :code, :code do
              code_config do
                {
                  mode: 'text/x-ruby'
                }
              end
            end

            edit do
              field :namespace, :enum_edit, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :name, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY


              field :source_data_type do
                shared_read_only
                inline_edit false
                inline_add false
              end
              field :bulk_source do
                shared_read_only
              end
              field :code_warnings
              field :code, :code do
                help { 'Required' }
              end
            end

            show do
              field :namespace
              field :name
              field :source_data_type
              field :mime_type
              field :file_extension
              field :code_warnings
              field :code
              field :updated_at
            end

            fields :namespace, :name, :source_data_type, :mime_type, :file_extension, :code, :updated_at
          end
        end

      end
    end
  end
end
