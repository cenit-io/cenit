module RailsAdmin
  module Models
    module Setup
      module RubyParserAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Transforms'
            label 'Ruby Parser'
            navigation_icon 'fa fa-sign-in'
            weight 410
            object_label_method { :custom_title }

            hide_on_navigation

            configure :namespace, :enum_edit

            configure :discard_events, :toggle_boolean

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


              field :target_data_type do
                shared_read_only
                inline_edit false
                inline_add false
              end
              field :discard_events do
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
              field :target_data_type
              field :discard_events
              field :code_warnings
              field :code
              field :updated_at
            end

            fields :namespace, :name, :target_data_type, :code, :updated_at
          end
        end
      end
    end
  end
end
