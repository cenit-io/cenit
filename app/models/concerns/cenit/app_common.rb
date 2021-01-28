module Cenit
  module AppCommon
    extend ActiveSupport::Concern

    included do

      accepts_nested_attributes_for :application_parameters, allow_destroy: true

      after_initialize :bind_provider
      before_validation :bind_provider
      before_save :prepare_for_save
    end


    def bind_provider
      self.provider_id = Setup::Oauth2Provider.build_in_provider_id unless provider_id == Setup::Oauth2Provider.build_in_provider_id
    end

    def validates_configuration
      configuration.validate
      configuration.errors.full_messages
    end

    def prepare_for_save
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
      @mongoff_model ||= Mongoff::Model.for(
        data_type: self.class.data_type,
        schema: configuration_schema,
        name: self.class.configuration_model_name
      )
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

    def conformed_request_token_parameters(template_parameters = {})
      {}
    end

    def conformed_request_token_headers(template_parameters = {})
      {}
    end

    module ClassMethods
      def preferred_authorization_class(_provider)
        Setup::AppAuthorization
      end

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
        klass = Setup::Collection.reflect_on_association(type.to_s.downcase.tr(' ', '_').pluralize).klass
        klass = case klass
                  when Setup::RemoteOauthClient
                    Setup::OauthClient
                  when Setup::PlainWebhook
                    Setup::Webhook
                  else
                    klass
                end
        {
          referenced: true,
          '$ref': {
            namespace: klass.data_type.namespace,
            name: klass.data_type.name
          }
        }
      end

      def configuration_model_name
        "#{self}::Config"
      end

      def stored_properties_on(record)
        stored = %w(namespace name identifier secret created_at updated_at)
        %w(application_parameters).each { |f| stored << f if record.send(f).present? }
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
