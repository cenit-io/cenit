module Setup
  class RemoteOauthClient < OauthClient
    include SharedEditable
    include Parameters
    include WithTemplateParameters
    include AuthorizationClientCommon

    build_in_data_type
      .including(:provider)
      .referenced_by(:_type, :provider, :name)
      .protecting(:identifier, :secret)
      .and(label: '{{provider.namespace}} | {{provider.name}} | {{name}}')

    parameters :request_token_parameters, :request_token_headers, :template_parameters

  end
end
