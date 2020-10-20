module Setup
  class Application < OauthClient
    include NamespaceNamed
    include Slug
    include Cenit::AppConfig
    include Cenit::AppCommon
    include RailsAdmin::Models::Setup::ApplicationAdmin

    origins :app

    default_origin :app

    build_in_data_type.with(:namespace, :name, :actions, :application_parameters)
    build_in_data_type.referenced_by(:namespace, :name, :_type).and(properties: { configuration: {} })

    additional_config_schema(
      properties: {
        authentication_method: {
          type: 'string',
          enum: ['User credentials', 'Application ID'],
          group: 'Security',
          default: 'User credentials'
        }
      },
      required: %w(authentication_method)
    )

    allow :delete, :delete_all, :new, :copy

    embeds_many :actions, class_name: Setup::Action.to_s, order: { priority: :asc }, inverse_of: :application

    accepts_nested_attributes_for :actions, allow_destroy: true

    def prepare_for_save
      if new_record?
        configuration['authentication_method'] ||= 'User credentials'
      end

      super
    end

    class << self

      def stored_properties_on(record)
        stored = %w(namespace name identifier secret created_at updated_at)
        %w(actions application_parameters).each { |f| stored << f if record.send(f).present? }
        stored << 'configuration'
        stored
      end
    end
  end
end
