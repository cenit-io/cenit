module Setup
  class Oauth2Scope
    include SharedEditable
    include CustomTitle
    include BuildIn

    origins origins_config, :cenit

    build_in_data_type
      .referenced_by(:name, :provider)
      .and(label: '{{provider.namespace}} | {{provider.name}} | {{name}}')

    field :name, type: String
    field :description, type: String

    belongs_to :provider, class_name: Setup::Oauth2Provider.to_s, inverse_of: nil

    validates_presence_of :name, :provider
    validates_uniqueness_of :name, scope: :provider

    def scope_title
      provider&.custom_title
    end

    def key
      name
    end

    def value
      name
    end

  end
end
