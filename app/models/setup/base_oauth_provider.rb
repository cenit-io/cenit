module Setup
  class BaseOauthProvider
    include CenitUnscoped
    include MandatoryNamespace
    include CrossTenancy
    include ClassHierarchyAware

    abstract_class true

    BuildInDataType[self].referenced_by(:namespace, :name)

    field :response_type, type: String
    field :authorization_endpoint, type: String
    field :token_endpoint, type: String
    field :token_method, type: String

    has_many :clients, class_name: Setup::OauthClient.to_s, inverse_of: :provider

    validates_presence_of :name, :response_type, :authorization_endpoint, :token_endpoint, :token_method
    validates_inclusion_of :response_type, in: ->(provider) { provider.response_type_enum }
    validates_inclusion_of :token_method, in: ->(provider) { provider.token_method_enum }

    def response_type_enum
      ['code']
    end

    def token_method_enum
      %w(POST GET)
    end
  end
end