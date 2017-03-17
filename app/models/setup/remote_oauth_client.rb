module Setup
  class RemoteOauthClient < OauthClient
    include SharedEditable
    include RailsAdmin::Models::Setup::RemoteOauthClientAdmin

    build_in_data_type.including(:provider).referenced_by(:_type, :provider, :name).protecting(:identifier, :secret)

    field :identifier, type: String
    field :secret, type: String

    validates_uniqueness_of :name, scope: :provider

    def get_identifier
      attributes[:identifier]
    end

    def get_secret
      attributes[:secret]
    end

    def scope_title
      provider && provider.custom_title
    end
    
  end
end
