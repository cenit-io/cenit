module Setup
  class Oauth2Provider < Setup::BaseOauthProvider
    include CenitUnscoped
    include RailsAdmin::Models::Setup::Oauth2ProviderAdmin

    build_in_data_type.referenced_by(:namespace, :name).excluding(:origin, :tenant)

    field :scope_separator, type: String

    validates_length_of :scope_separator, maximum: 1

    class << self

      def build_in_provider_id
        @build_in_provider_id ||=
          begin
            oauth_provider = Setup::Oauth2Provider.find_or_create_by(namespace: 'Cenit', name: 'OAuth')
            oauth_provider.authorization_endpoint = "#{Cenit.homepage}#{Cenit.oauth_path}/authorize"
            oauth_provider.token_endpoint =
              if Cenit.oauth_token_end_point.to_s.to_sym == :embedded
                "#{Cenit.homepage}#{Cenit.oauth_path}/token"
              else
                Cenit.oauth_token_end_point
              end
            oauth_provider.response_type = :code
            oauth_provider.token_method = :POST
            if oauth_provider.changed?
              Setup::SystemReport.create_with(
                message: 'Cenit OAuth 2.0 provider configuration changed',
                type: :warning,
                attachment: {
                  filename: 'changes.json',
                  contentType: 'application/json',
                  body: JSON.pretty_generate(oauth_provider.changes)
                }
              )
              oauth_provider.save
            end
            unless oauth_provider.origin == :cenit
              Setup::SystemReport.create(
                message: "Cenit OAuth 2.0 provider configuration crossed from #{oauth_provider.origin} to cenit",
                type: :warning
              )
              oauth_provider.cross(:cenit)
            end
            scopes = Cenit::OauthScope::NON_ACCESS_TOKENS +
              Cenit::OauthScope::ACCESS_TOKENS.collect { |method| "#{method} {{#{method}}}" } +
              ['{{scope}}']
            scopes.each do |scope_name|
              Setup::Oauth2Scope.find_or_create_by(origin: :cenit, provider_id: oauth_provider.id, name: scope_name)
            end
            oauth_provider.id
          end
      end
    end
  end
end
