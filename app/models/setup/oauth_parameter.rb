module Setup
  class OauthParameter
    include CenitUnscoped

    BuildInDataType.regist(self)

    field :key, type: String
    field :value, type: String

    embedded_in :authorization, class_name: Setup::BaseOauthAuthorization.to_s, inverse_of: :parameters

    validates_presence_of :key

    def to_s
      "#{key}: #{value}"
    end
  end
end