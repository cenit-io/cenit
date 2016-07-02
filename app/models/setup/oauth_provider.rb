module Setup
  class OauthProvider < Setup::BaseOauthProvider
    include CenitUnscoped

    build_in_data_type.referenced_by(:namespace, :name).excluding(:origin, :tenant, :clients)

    field :request_token_endpoint, type: String

    validates_presence_of :request_token_endpoint
  end
end