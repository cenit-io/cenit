module Setup
  class OauthClient
    include CenitScoped
    include CrossOrigin::CenitDocument
    include CustomTitle
    include RailsAdmin::Models::Setup::OauthClientAdmin
    include ClassHierarchyAware

    abstract_class true

    origins :app, :default, -> { Cenit::MultiTenancy.tenant_model.current && :owner }, :shared

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

    field :name, type: String
    belongs_to :provider, class_name: Setup::BaseOauthProvider.to_s, inverse_of: nil

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

    def create_authorization!(auth_data = {})
      auth_class =
        if provider.class == Setup::OauthProvider
          Setup::OauthAuthorization
        else
          Setup::Oauth2Authorization
        end
      auth = auth_class.new(namespace: auth_data[:namespace], client_id: id, metadata: auth_data[:metadata])
      auth.name = auth_data[:name] || "#{provider.name.to_title} #{auth_class.to_s.split('::').last.to_title} #{auth.id}"
      if auth_class == Setup::Oauth2Authorization
        scope_names = auth_data[:scopes] || []
        if scope_names.is_a?(Array)
          scopes = Setup::Oauth2Scope.where(provider: provider).any_in(name: scope_names)
        else
          unless (templates = auth_data[:template_parameters])
            templates = auth_data[:template_parameters] = {}
          end
          templates['scope'] = scope_names
          scopes = [provider.default_scope]
          scope_names = [scopes.first.name]
        end
        scope_names.each do |scope_name|
          if (scope = scopes.detect { |scp| scp.name == scope_name })
            auth.scopes << scope
          end
        end
      end
      [:parameters, :template_parameters].each do |param|
        if (params = auth_data[param]).is_a?(Hash)
          association = auth.send(param)
          params.each do |key, value|
            association.new(key: key, value: value)
          end
        end
      end
      auth.save!
      auth
    end

  end
end
