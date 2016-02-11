module Setup
  class BasicAuthorization < Setup::Authorization
    include CenitScoped
    include AuthorizationHeader

    BuildInDataType.regist(self).with(:namespace, :name).referenced_by(:namespace, :name)

    field :username, type: String
    field :password, type: String

    validates_presence_of :username, :password

    auth_template_parameters basic_auth: :build_auth_header

    def build_auth_header(template_parameters)
      'basic ' + ::Base64.encode64("#{username}:#{password}").gsub("\n", '')
    end
  end
end