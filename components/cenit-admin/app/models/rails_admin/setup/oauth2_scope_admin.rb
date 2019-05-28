module RailsAdmin
  module Models
    module Setup
      module Oauth2ScopeAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Security'
            navigation_icon 'fa fa-users'
            weight 320
            label 'OAuth 2.0 Scope'
            object_label_method { :custom_title }

            fields :provider, :name, :description, :updated_at
          end
        end
      end
    end
  end
end
