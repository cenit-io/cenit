module RailsAdmin
  module Models
    module Setup
      module GenericAuthorizationClientAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Security'
            label 'Generic Client'
            navigation_icon 'fa fa-user'
            weight 300
            parent ::Setup::AuthorizationClient
            object_label_method { :custom_title }

            configure :tenant do
              visible { ::User.current_super_admin? }
              read_only { true }
              help ''
            end

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

            fields :provider, :name, :identifier, :secret, :tenant, :template_parameters, :updated_at
          end
        end
      end
    end
  end
end
