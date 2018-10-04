module RailsAdmin
  module Models
    module Setup
      module AuthorizationClientAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Security'
            navigation_icon 'fa fa-user'
            label 'Authorization Client'
            weight 300
            object_label_method { :custom_title }

            configure :identifier do
              pretty_value do
                (value || '<i class="icon-lock"/>').html_safe
              end
            end

            configure :secret do
              pretty_value do
                (value || '<i class="icon-lock"/>').html_safe
              end
            end

            fields :provider, :name, :identifier, :secret, :updated_at
          end
        end

      end
    end
  end
end
