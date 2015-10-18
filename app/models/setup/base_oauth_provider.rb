module Setup
  class BaseOauthProvider
    include CenitUnscoped
    include CenitReservedNamespace
    include CrossTenancy

    Setup::Models.exclude_actions_for self, :all

    BuildInDataType.regist(self).referenced_by(:namespace, :name)

    field :response_type, type: String
    field :authorization_endpoint, type: String
    field :token_endpoint, type: String
    field :token_method, type: String

    embeds_many :parameters, class_name: Setup::OauthParameter.to_s, inverse_of: :provider

    has_many :clients, class_name: Setup::OauthClient.to_s, inverse_of: :provider

    validates_presence_of :name, :response_type, :authorization_endpoint, :token_endpoint, :token_method
    validates_inclusion_of :response_type, in: ->(provider) { provider.response_type_enum }
    validates_inclusion_of :token_method, in: ->(provider) { provider.token_method_enum }

    accepts_nested_attributes_for :parameters, allow_destroy: true

    def response_type_enum
      ['code']
    end

    def token_method_enum
      %w(POST GET)
    end
  end
end