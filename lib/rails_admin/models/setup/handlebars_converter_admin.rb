module RailsAdmin
  module Models
    module Setup
      module HandlebarsConverterAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Transforms'
            label 'Handlebars Converter'
            weight 410
            object_label_method { :custom_title }

            visible { User.current_super_admin? && group_visible }

            configure :code, :code do
              code_config do
                {
                  mode: case bindings[:object].code_extension
                        when '.json'
                          'application/json'
                        when '.xml'
                          'application/xml'
                        else
                          'text/plain'
                        end
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

              field :target_data_type do
                shared_read_only
                inline_edit false
                inline_add false
              end

              field :code
            end

            fields :namespace, :name, :source_data_type, :target_data_type, :code, :updated_at
          end
        end

      end
    end
  end
end
