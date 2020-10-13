module Cenit
  module AppConfig
    extend ActiveSupport::Concern

    BANED_PARAMETER_NAMES = %w(authentication_method logo redirect_uris)

    included do
      belongs_to :application_id, class_name: ApplicationId.to_s, inverse_of: nil

      embeds_many :application_parameters, class_name: Cenit::ApplicationParameter.to_s, inverse_of: :application
      Cenit::ApplicationParameter.embedded_in :application, class_name: self.to_s, inverse_of: :application_parameters

      field :secret_token, type: String
      field :configuration_attributes, type: Hash, default: {}

      before_save do
        self.application_id ||= ApplicationId.new
        self.secret_token ||= Cenit::Token.friendly(60)

        if configuration['logo'].blank?
          configuration['logo'] = Identicon.data_url_for identifier
        end

        self.class.configuration_callbacks.each do |callback|
          instance_eval(&callback)
        end

        validates_configuration.each do |error|
          errors.add(:base, error)
        end

        errors.blank?
      end

      after_save { application_id.save if application_id.new_record? }

      after_destroy { application_id&.destroy }
    end

    def validates_configuration
      JSON::Validator.fully_validate(configuration_schema, configuration_attributes, errors_as_objects: true).collect do |error|
        error[:message]
      end
    end

    def registered
      application_id&.registered
    end

    def registered?
      registered
    end

    def identifier
      application_id&.identifier
    end

    def slug_id
      application_id && (application_id.slug.presence || application_id.identifier)
    end

    def configuration
      configuration_attributes
    end

    def configuration_schema
      schema = self.class.additional_config_schema.deep_merge(
        type: 'object',
        properties: {
          logo: {
            type: 'string',
            group: 'UI'
          },
          redirect_uris: {
            type: 'array',
            items: {
              type: 'string'
            },
            group: 'OAuth',
            default: ["#{Cenit.homepage}#{Cenit.oauth_path}/callback"]
          }
        }
      )
      required = schema[:required] || []
      required << 'redirect_uris' if registered?
      schema[:required] = required unless required.empty?
      properties = schema[:properties]
      application_parameters.each { |p| properties[p.name] = p.schema }
      schema.deep_stringify_keys
    end

    def oauth_name
      fail NotImplementedError
    end

    def user_id_for(access_token)
      access_token = OauthAccessToken.where(token: access_token, application_id_id: application_id_id).first
      if access_token&.alive? && access_token.access_grant && access_token.oauth_scope.openid?
        access_token.user_id
      else
        nil
      end
    end

    module ClassMethods

      def additional_config_schema(*schemas)
        if schemas.length == 0
          @additional_config_schema || {}
        else
          @additional_config_schema = schemas.reduce(&:deep_merge)
        end
      end

      def before_validates_configuration(&block)
        block && configuration_callbacks << block
      end

      def configuration_callbacks
        @configuration_callbacks ||= []
      end

      def additional_parameter_types
        []
      end

      def parameter_type_schema(type)
        {
          '$ref': type.to_s
        }
      end
    end
  end
end