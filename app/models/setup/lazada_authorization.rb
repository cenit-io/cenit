module Setup
  class LazadaAuthorization < Setup::Oauth2Authorization
    include CenitScoped
    include RailsAdmin::Models::Setup::LazadaAuthorizationAdmin

    build_in_data_type.with(:namespace, :name, :provider, :client, :parameters, :template_parameters, :scopes)
    build_in_data_type.referenced_by(:namespace, :name)

    auth_template_parameters access_token: ->(oauth2_auth) { oauth2_auth.fresh_access_token }

    def token_params(params = {}, template_parameters = {})
      super
      sign(
        parameters: params,
        template_parameters: { url: client.provider.token_endpoint }
      )
      params
    end

    def sign(msg)
      unless (parameters = msg[:parameters])
        parameters = msg[:parameters] = {}
      end
      parameters[:app_key] = client.get_identifier
      parameters[:sign_method] = 'sha256'
      parameters[:timestamp] = (Time.now.utc.to_f * 1000).to_i
      template_parameters = msg[:template_parameters] || {}
      path = URI.parse(
        template_parameters[:url].to_s.gsub(%r{\/+\Z}, '') +
          ('/' + template_parameters[:path].to_s).gsub(%r{\/+}, '/')
      ).path.to_s
      path.gsub!(/\Arest\//, '')
      sign = (path + parameters.sort.flatten.join).hmac_hex_sha256(client.get_secret).upcase
      parameters[:sign] = sign
    end
  end
end
