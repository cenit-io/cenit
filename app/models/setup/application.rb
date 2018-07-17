module Setup
  class Application < OauthClient
    include NamespaceNamed
    include Slug
    include Cenit::Oauth::AppConfig
    include RailsAdmin::Models::Setup::ApplicationAdmin

    origins :app

    default_origin :app

    build_in_data_type.with(:namespace, :name, :actions, :application_parameters)
    build_in_data_type.referenced_by(:namespace, :name, :_type).and(properties: { configuration: {} })

    embeds_many :actions, class_name: Setup::Action.to_s, order: { path: :asc, method: :asc }, inverse_of: :application

    accepts_nested_attributes_for :actions, :application_parameters, allow_destroy: true

    before_validation do
      self.provider_id = Setup::Oauth2Provider.build_in_provider_id
    end

    def validates_configuration
      configuration.validate
      configuration.errors.full_messages
    end

    before_save do
      self.configuration_attributes = configuration.attributes

      params = application_parameters.sort_by(&:name).sort_by(&:group_s)
      self.application_parameters = params

      errors.blank?
    end

    def configuration
      @config ||= configuration_model.new(configuration_attributes)
    end

    def configuration=(data)
      unless data.is_a?(Hash)
        data =
          if data.is_a?(String)
            JSON.parse(data)
          else
            data.try(:to_json) || {}
          end
      end
      @config = configuration_model.new_from_json(data)
    end

    def configuration_model
      @mongoff_model ||= Mongoff::Model.for(data_type: self.class.data_type,
        schema: configuration_schema,
        name: self.class.configuration_model_name,
        cache: false)
    end

    def oauth_name
      custom_title
    end

    def get_identifier
      identifier
    end

    def secret
      get_secret
    end

    def get_secret
      secret_token
    end

    def tenant
      Cenit::MultiTenancy.tenant_model.current
    end

    def conformed_request_token_parameters(template_parameters = {})
      {}
    end

    def conformed_request_token_headers(template_parameters = {})
      {}
    end

    class << self
      def share_options
        options = super
        ignore = options[:ignore] || []
        ignore = [ignore] unless ignore.is_a?(Array)
        ignore << :logo
        options
      end

      def additional_parameter_types
        Setup::Collection.reflect_on_all_associations(:has_and_belongs_to_many).collect { |r| r.name.to_s.singularize.to_title }
      end

      def parameter_type_schema(type)
        {
          '$ref': case (klass = Setup::Collection.reflect_on_association(type.to_s.downcase.tr(' ', '_').pluralize).klass)
                  when Setup::RemoteOauthClient
                    Setup::OauthClient
                  when Setup::PlainWebhook
                    Setup::Webhook
                  else
                    klass
                  end.to_s
        }
      end

      def configuration_model_name
        "#{Setup::Application}::Config"
      end

      def stored_properties_on(record)
        stored = %w(namespace name)
        %w(actions application_parameters).each { |f| stored << f if record.send(f).present? }
        stored << 'configuration'
        stored
      end

      def for_each_association(&block)
        super
        block.yield(name: :configuration, embedded: false, many: false)
      end

    end
  end
end
