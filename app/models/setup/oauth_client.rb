module Setup
  class OauthClient
    include CrossTenancy
    include CustomTitle

    build_in_data_type.including(:provider).referenced_by(:provider, :name).protecting(:identifier, :secret)

    field :name, type: String
    belongs_to :provider, class_name: Setup::BaseOauthProvider.to_s, inverse_of: :clients

    field :identifier, type: String
    field :secret, type: String

    validates_presence_of :provider, :name
    validates_uniqueness_of :name, scope: :provider

    def scope_title
      provider && provider.custom_title
    end

    def create_authorization!(auth_data={})
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
        scope_names = [scope_names] unless scope_names.is_a?(Array)
        scopes = Setup::Oauth2Scope.where(provider: provider).any_in(name: scope_names)
        scope_names.each do |scope_name|
          if (scope = scopes.detect { |scp| scp.name == scope_name })
            auth.scopes << scope
          end
        end
      end
      auth.save!
      auth
    end
  end
end