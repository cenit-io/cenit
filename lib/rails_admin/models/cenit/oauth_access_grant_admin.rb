module RailsAdmin
  module Models
    module Cenit
      module OauthAccessGrantAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Security'
            label 'Access Grants'
            weight 340

            fields :created_at, :application_id, :scope
          end
        end

      end
    end
  end
end
