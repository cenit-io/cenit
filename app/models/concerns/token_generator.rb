module TokenGenerator
  extend ActiveSupport::Concern

  included do
    field :authentication_token, as: :token, type: String

    validates_uniqueness_of :token

    before_validation :ensure_token
  end

  def ensure_token
    self[:token] = generate_token unless self[:token].present?
  end

  def generate_token
    loop do
      token = Devise.friendly_token
      break token unless self.class.where(token: token).exists?
    end
  end
end