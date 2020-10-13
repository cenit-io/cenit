module Setup
  class RemoteOauthClient < OauthClient
    include SharedEditable
    include Parameters
    include WithTemplateParameters
    include AuthorizationClientCommon
    include RailsAdmin::Models::Setup::RemoteOauthClientAdmin

    build_in_data_type.including(:provider).referenced_by(:_type, :provider, :name).protecting(:identifier, :secret)

    allow :delete, :delete_all, :new, :copy

    parameters :request_token_parameters, :request_token_headers, :template_parameters

  end
end
