class CenitToken
  include Mongoid::Document
  include Mongoid::Timestamps

  field :token, type: String
  field :token_span, type: Integer, default: -> { self.class.default_token_span }
  field :data

  before_save :ensure_token

  def ensure_token
    self.token = Devise.friendly_token(self.class.token_length) unless token.present?
    true
  end

  def long_term?
    token_span.nil?
  end

  class << self
    def token_length(*args)
      if (arg = args[0])
        @token_length = arg
      else
        @token_length ||= 20
      end
    end

    def default_token_span(*args)
      if (arg = args[0])
        @token_span = arg.to_i rescue nil
      else
        @token_span
      end
    end
  end
end