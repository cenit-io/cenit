module RailsAdmin
  module Models
    module Setup
      module RemoteOauthClientAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Security'
            label 'Remote OAuth Client'
            navigation_icon 'fa fa-user'
            weight 300
            object_label_method { :custom_title }

            configure :tenant do
              visible { Account.current_super_admin? }
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

            fields :provider, :name, :identifier, :secret, :tenant, :request_token_parameters, :request_token_headers, :updated_at
          end
        end

      end
    end
  end
end
