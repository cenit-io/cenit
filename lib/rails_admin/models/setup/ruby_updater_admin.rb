module RailsAdmin
  module Models
    module Setup
      module RubyUpdaterAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Transforms'
            label 'Ruby Updater'
            weight 410
            object_label_method { :custom_title }

            hide_on_navigation

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
                help "Events won't be fired for created or updated records if checked"
              end

              field :source_handler do
                shared_read_only
                help { 'Handle targets on code' }
              end

              field :code
            end

            fields :namespace, :name, :target_data_type, :discard_events, :code, :updated_at
          end
        end

      end
    end
  end
end
