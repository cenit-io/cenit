module Setup
  class BasicAuthorization < Setup::Authorization
    include CenitScoped
    include AuthorizationHeader
    include ::RailsAdmin::Models::Setup::BasicAuthorizationAdmin

    build_in_data_type.with(
      :namespace,
      :name,
      :username,
      :password
    ).referenced_by(:namespace, :name).protecting(:username, :password)

    field :username, type: String
    field :password, type: String

    auth_template_parameters username: :username, password: :password, basic_auth: :basic_auth

    def build_auth_header(_template_parameters)
      basic_auth
    end

    def basic_auth
      'Basic ' + ::Base64.encode64("#{username}:#{password}").delete("\n")
    end

    def authorized?
      username.present? && password.present?
    end
    
  end
end
