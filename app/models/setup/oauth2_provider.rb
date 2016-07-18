module Setup
  class Oauth2Provider < Setup::BaseOauthProvider
    include CenitUnscoped

    build_in_data_type.referenced_by(:namespace, :name).excluding(:origin, :tenant)

    field :scope_separator, type: String

    validates_length_of :scope_separator, maximum: 1
  end
end