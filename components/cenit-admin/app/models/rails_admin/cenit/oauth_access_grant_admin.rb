module RailsAdmin
  module Models
    module Cenit
      module OauthAccessGrantAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Security'
            navigation_icon 'fa fa-key'
            label 'Access Grants'
            weight 340

            configure :application_id do
              read_only true
              help ''
            end
            configure :scope, :cenit_oauth_scope do
              help ''
            end

            fields :created_at, :application_id, :scope
          end
        end
      end
    end
  end
end
