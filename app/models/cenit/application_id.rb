module Cenit
  class ApplicationId
    include Mongoid::Document
    include Mongoid::Timestamps
    include RailsAdmin::Models::Cenit::ApplicationIdAdmin

    field :tenant_id

    field :identifier, type: String
    field :oauth_name, type: String
    field :slug, type: String, default: ''

    validates_length_of :oauth_name, within: 6..20, allow_nil: true
    validates_length_of :slug, maximum: 255
    validates_format_of :slug, with: /\A([a-z][a-z0-9]*([_-][a-z0-9]+)?)?\Z/

    validate do
      [:oauth_name, :slug].each do |field|
        if self[field].blank?
          remove_attribute(field)
        else
          self[field] = self[field].strip
          if self.class.where(:id.ne => id).and(field => self[field]).exists?
            errors.add(field, 'is already taken')
          end
        end
      end
      errors.blank?
    end

    before_save do
      self.tenant ||= Cenit::MultiTenancy.tenant_model.current_tenant
      self.identifier ||= (id.to_s + Token.friendly(60))
      if @redirect_uris
        app.configuration['redirect_uris'] = @redirect_uris
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

    def tenant
      @tenant ||= Cenit::MultiTenancy.tenant_model.unscoped.where(id: tenant_id).first
    end

    def tenant=(tenant)
      self.tenant_id = (@tenant = tenant) ? tenant.id : nil
      tenant
    end

    def app
      @app ||= tenant && tenant.switch do
        Setup::Application.where(application_id: self).first
      end
    end

    def name
      oauth_name.presence || (app && app.oauth_name)
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
      [:slug, :oauth_name, :redirect_uris].each { |field| send("#{field}=", data[field]) }
      self
    end
  end
end