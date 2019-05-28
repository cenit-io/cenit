module Cenit
  class OauthAccessGrant
    include Setup::CenitScoped
    include CrossOrigin::Document

    # TODO Include App information field
    build_in_data_type.with(:scope)

    deny :all
    allow :index, :show, :delete, :edit

    origins :default, -> { Cenit::MultiTenancy.tenant_model.current && :owner }

    belongs_to :application_id, class_name: Cenit::ApplicationId.to_s, inverse_of: nil
    field :scope, type: String

    attr_readonly :application_id_id

    before_save :validate_scope

    after_destroy :clear_oauth_tokens

    after_save :check_origin

    def check_origin
      cross(oauth_scope.multi_tenant? ? :owner : :default)
    end

    def validate_scope
      if (scope = oauth_scope.access_by_ids).valid?
        self.scope = scope.to_s
      else
        errors.add(:scope, 'is not valid')
      end
      errors.blank?
    end

    def oauth_scope
      Cenit::OauthScope.new(scope)
    end

    def clear_oauth_tokens
      [
        OauthAccessToken,
        OauthRefreshToken
      ].each do |oauth_token_model|
        oauth_token_model.where(tenant: Account.current, application_id: application_id).delete_all
      end
    end
  end
end
