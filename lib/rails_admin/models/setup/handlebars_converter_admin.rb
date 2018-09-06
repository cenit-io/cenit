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

            hide_on_navigation

            configure :namespace, :enum_edit

            configure :discard_events, :toggle_boolean

            configure :code_warnings, :code_warnings

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

              field :discard_events do
                shared_read_only
                help "Events won't be fired for created or updated records if checked"
              end

              field :code_warnings

              field :code
            end

            show do
              field :namespace
              field :name
              field :source_data_type
              field :target_data_type
              field :discard_events
              field :code_warnings
              field :code
              field :updated_at
            end

            fields :namespace, :name, :source_data_type, :target_data_type, :discard_events, :code, :updated_at
          end
        end

      end
    end
  end
end
