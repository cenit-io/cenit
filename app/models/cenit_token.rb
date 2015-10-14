class CenitToken
  include Mongoid::Document
  include Mongoid::Timestamps

  field :token, type: String
  field :data

  before_save :ensure_token

  def ensure_token
    self.token = Devise.friendly_token unless token.present?
    true
  end
end