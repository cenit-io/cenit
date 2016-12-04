module RailsAdmin
  module Models
    module Setup
      module Oauth2ScopeAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Security'
            weight 320
            label 'OAuth 2.0 Scope'
            object_label_method { :custom_title }

            configure :tenant do
              visible { Account.current_super_admin? }
              read_only { true }
              help ''
            end

            fields :provider, :name, :description, :tenant, :updated_at
          end
        end

      end
    end
  end
end
