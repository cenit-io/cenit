module Cenit
  class OauthAccessGrant
    include Setup::CenitScoped
    include CrossOrigin::Document

    build_in_data_type
      .with(:scope, :origin)
      .and(
        label: '{{app_name}} [access]',
        properties: {
          app_name: {
            type: 'string',
            virtual: true
          }
        },
        with_origin: true
      )

    deny :create

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
      abort_if_has_errors
    end

    def app_name
      application_id&.name
    end

    def oauth_scope
      Cenit::OauthScope.new(scope)
    end

    def tokens
      OauthAccessToken.where(tenant: Account.current, application_id: application_id)
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