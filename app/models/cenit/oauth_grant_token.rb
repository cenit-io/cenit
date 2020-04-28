module Cenit
  module OauthGrantToken
    extend ActiveSupport::Concern

    include OauthTokenCommon

    included do
      belongs_to :application_id, class_name: ApplicationId.to_s, inverse_of: nil

      before_destroy do
        current_tenant = ::Tenant.current
        unless current_tenant && current_tenant.id == tenant_id
          errors.add(:base, 'Destroy action is out of current scope')
        end
        errors.blank?
      end
    end

    def access_grant
      @access_grant ||= tenant.switch { Cenit::OauthAccessGrant.where(application_id: application_id).first }
    end

    def scope
      access_grant.scope
    end

    def oauth_scope
      access_grant.oauth_scope
    end
  end
end