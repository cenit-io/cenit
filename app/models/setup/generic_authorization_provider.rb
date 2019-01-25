module Setup
  class GenericAuthorizationProvider < AuthorizationProvider
    include ::RailsAdmin::Models::Setup::GenericAuthorizationProviderAdmin

    build_in_data_type.referenced_by(:namespace, :name)

  end
end
