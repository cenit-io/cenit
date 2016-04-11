class ApplicationId
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :account, class_name: Account.to_s, inverse_of: nil

  field :identifier, type: String

  before_save do
    self.identifier ||= (id.to_s + Devise.friendly_token(60))
    self.account ||= Account.current
  end

end