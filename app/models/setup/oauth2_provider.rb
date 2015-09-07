module Setup
  class Oauth2Provider
    include CenitUnscoped

    Setup::Models.exclude_actions_for self, :all

    BuildInDataType.regist(self).referenced_by(:name)

    field :name, type: String
    field :response_type, type: String
    field :authorization_endpoint, type: String
    field :token_endpoint, type: String
    field :access_token_request_method, type: String

    embeds_many :parameters, class_name: Setup::Oauth2Parameter.to_s, inverse_of: :provider

    has_many :clients, class_name: Setup::Oauth2Client.to_s, inverse_of: :provider
    has_many :scopes, class_name: Setup::Oauth2Scope.to_s, inverse_of: :provider

    validates_presence_of :name, :response_type, :authorization_endpoint, :token_endpoint, :access_token_request_method
    validates_inclusion_of :response_type, in: ->(provider) { provider.response_type_enum }
    validates_inclusion_of :access_token_request_method, in: ->(provider) { provider.access_token_request_method_enum }

    accepts_nested_attributes_for :parameters, allow_destroy: true

    def response_type_enum
      ['code']
    end

    def access_token_request_method_enum
      %w(POST GET)
    end
  end
end