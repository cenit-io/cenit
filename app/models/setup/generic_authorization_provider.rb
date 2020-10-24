module Setup
  class GenericAuthorizationProvider < AuthorizationProvider

    build_in_data_type.referenced_by(:namespace, :name)

  end
end
