module Setup
  class OauthParameter
    include CenitUnscoped

    Setup::Models.exclude_actions_for self, :all

    BuildInDataType.regist(self)

    field :key, type: String
    field :value, type: String

    embedded_in :provider, class_name: Setup::BaseOauthProvider.to_s, inverse_of: :parameters

    validates_presence_of :key

    def to_s
      "#{key}: #{value}"
    end
  end
end