module Setup
  class GenericAuthorizationClient < AuthorizationClient
    include SharedEditable
    include Parameters
    include WithTemplateParameters
    include AuthorizationClientCommon

    build_in_data_type.including(:provider).referenced_by(:_type, :provider, :name).protecting(:identifier, :secret)

    parameters :template_parameters

  end
end
