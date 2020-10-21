module Setup
  class AuthorizationClient
    include CenitScoped
    include CrossOrigin::CenitDocument
    include CustomTitle
    include RailsAdmin::Models::Setup::AuthorizationClientAdmin
    include ClassHierarchyAware

    abstract_class true

    origins :app, :default, -> { Cenit::MultiTenancy.tenant_model.current && :owner }, :shared, :admin

    build_in_data_type.including(:provider).and(
      properties: {
        identifier: {
          type: 'string'
        },
        secret: {
          type: 'string'
        }
      }
    ).protecting(:identifier, :secret).referenced_by(:_type, :provider, :namespace, :name)

    deny :destroy, :delete_all, :new, :copy

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
