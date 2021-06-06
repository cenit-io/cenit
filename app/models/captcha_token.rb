class CaptchaToken < Cenit::BasicToken

  field :email, type: String
  field :code, type: String
  field :count, type: Integer

  before_save :ensure_token, :generate_code

  def ensure_token
    self.token = Devise.friendly_token unless token.present?
  end

  def generate_code
    chars = ('a'..'z').to_a
    code = ''
    (Cenit.captcha_length || 5).times { code += chars[rand(chars.length)] }
    self.code = code
  end

  def recode
    generate_code
    save
  end
end