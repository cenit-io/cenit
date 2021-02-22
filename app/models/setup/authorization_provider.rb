module Setup
  class AuthorizationProvider
    include SharedEditable
    include MandatoryNamespace
    include ClassHierarchyAware
    include BuildIn

    origins origins_config, :cenit

    abstract_class true

    build_in_data_type
      .referenced_by(:namespace, :name)
      .and_polymorphic(
        label: '{{namespace}} | {{name}}'
      )

    field :authorization_endpoint, type: String

    class << self

      def collectionizable_name
        Setup::BaseOauthProvider.to_s #TODO For legacy MongoDB collection
      end
    end
  end
end
