module TokenGenerator
  extend ActiveSupport::Concern

  included do
    field :authentication_token, as: :token, type: String

    validates_uniqueness_of :token

    before_validation :ensure_token
  end

  def regenerate_token
    self[:authentication_token] = generate_token
  end

  def ensure_token
    allow_generate = self.respond_to?(:owner) ? self.owner == User.current : true
    self[:authentication_token] = generate_token if allow_generate && self[:authentication_token].blank?
  end

  def generate_token
    loop do
      token = Devise.friendly_token
      break token unless self.class.where(token: token).exists?
    end
  end
end