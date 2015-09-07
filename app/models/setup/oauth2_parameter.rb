module Setup
  class Oauth2Parameter
    include CenitUnscoped

    Setup::Models.exclude_actions_for self, :all

    BuildInDataType.regist(self)

    field :key, type: String
    field :value, type: String

    embedded_in :provider, class_name: Setup::Oauth2Provider.to_s, inverse_of: :parameters

    validates_presence_of :key

    def to_s
      "#{key}: #{value}"
    end
  end
end