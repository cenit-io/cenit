module Setup
  class Application
    include CenitScoped
    include NamespaceNamed
    include Slug
    include Cenit::Oauth::AppConfig

    build_in_data_type.referenced_by(:namespace, :name).and('properties' => { 'configuration' => { 'type' => 'object' } })

    embeds_many :actions, class_name: Setup::Action.to_s, inverse_of: :application

    accepts_nested_attributes_for :actions, :application_parameters, allow_destroy: true

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

    def configuration_model
      @mongoff_model ||= Mongoff::Model.for(data_type: self.class.data_type,
                                            schema: configuration_schema,
                                            name: self.class.configuration_model_name)
    end

    def oauth_name
      custom_title
    end

    class << self

      def additional_parameter_types
        Setup::Collection.reflect_on_all_associations(:has_and_belongs_to_many).collect { |r| r.name.to_s.singularize.to_title }
      end

      def parameter_type_schema(type)
        {
          '$ref': Setup::Collection.reflect_on_association(type.to_s.downcase.gsub(' ', '_').pluralize).klass.to_s
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
        block.yield(name: :configuration, embedded: false)
      end
    end
  end
end