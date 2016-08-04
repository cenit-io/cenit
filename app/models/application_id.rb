class ApplicationId
  include Mongoid::Document
  include Mongoid::Timestamps
  include DynamicValidators

  belongs_to :account, class_name: Account.to_s, inverse_of: nil

  field :identifier, type: String
  field :oauth_name, type: String

  validates_uniqueness_in_presence_of :oauth_name
  validates_length_in_presence_of :oauth_name, within: 6..20

  before_save do
    self.identifier ||= (id.to_s + Devise.friendly_token(60))
    self.account ||= Account.current
    if @redirect_uris
      if (schema = app.configuration_schema['properties']['redirect_uris'])
        unless schema['type'] == 'array' && schema['items'].is_a?(Hash) && schema['items']['type'] == 'string'
          errors.add(:redirect_uris, 'Invalid redirect_uris parameter configuration')
        end
      else
        app.application_parameters.new(name: 'redirect_uris', type: 'string', many: true)
      end
      config_attrs = app.configuration_attributes || {}
      config_attrs['redirect_uris'] = @redirect_uris
      app.configuration = config_attrs
      unless app.save
        app.errors.full_messages.each { |error| errors.add(:base, "Invalid configuration: #{error}") }
      end
    end
    errors.blank?
  end

  before_destroy do
    if app
      errors.add(:base, 'User App is present')
      false
    else
      true
    end
  end

  def app
    @app ||= Setup::Application.with(account).where(application_id: self).first
  end

  def name
    oauth_name || (app && app.custom_title)
  end

  def redirect_uris
    @redirect_uris ||
      begin
        config_attrs = app.configuration_attributes || {}
        redirect_uris = config_attrs['redirect_uris'] || []
        redirect_uris = [redirect_uris.to_s] unless redirect_uris.is_a?(Enumerable)
        redirect_uris
      end
  end

  def redirect_uris=(uris)
    if uris.is_a?(String)
      uris = JSON.parse(uris) rescue [uris]
    end
    uris = [uris.to_s] unless uris.is_a?(Enumerable)
    @redirect_uris = uris.collect(&:to_s)
  end

  def registered
    registered?
  end

  def registered?
    oauth_name.present?
  end

  def regist_with(data)
    [:oauth_name, :redirect_uris].each { |field| send("#{field}=", data[field]) }
    self
  end
end