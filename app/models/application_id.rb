class ApplicationId
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :account, class_name: Account.to_s, inverse_of: nil

  field :identifier, type: String
  field :oauth_name, type: String

  before_save do
    self.identifier ||= (id.to_s + Devise.friendly_token(60))
    self.account ||= Account.current
  end

  def app
    @app ||= Setup::Application.with(account).where(application_id: self).first
  end

  def name
    oauth_name || app.custom_title
  end

  def redirect_uris
    redirect_uris = app.configuration_attributes['redirect_uris'] || []
    redirect_uris = [redirect_uris.to_s] unless redirect_uris.is_a?(Enumerable)
    redirect_uris
  end

  def registered?
    false
  end
end