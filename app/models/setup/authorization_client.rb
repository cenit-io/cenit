module Setup
  class AuthorizationClient
    include CenitScoped
    include CrossOrigin::CenitDocument
    include CustomTitle
    include ClassHierarchyAware

    abstract_class true

    origins :app, :default, -> { Cenit::MultiTenancy.tenant_model.current && :owner }, :shared, :admin

    build_in_data_type
      .including(:provider)
      .including_polymorphic(:origin)
      .protecting(:identifier, :secret)
      .referenced_by(:_type, :provider, :namespace, :name)
      .and(properties: {
        identifier: {
          type: 'string'
        },
        secret: {
          type: 'string'
        }
      })
      .and_polymorphic(with_origin: true)

    field :name, type: String
    belongs_to :provider, class_name: Setup::AuthorizationProvider.to_s, inverse_of: nil

    validates_presence_of :provider, :name

    def identifier
      fail NotImplementedError
    end

    def secret
      fail NotImplementedError
    end

    def get_identifier
      fail NotImplementedError
    end

    def get_secret
      fail NotImplementedError
    end

    def scope_title
      provider && provider.custom_title
    end

    class << self

      def collectionizable_name
        Setup::OauthClient.to_s #TODO For legacy MongoDB collection
      end
    end
  end
end
