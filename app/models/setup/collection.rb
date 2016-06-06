module Setup
  class Collection
    include CenitScoped
    include CollectionName

    BuildInDataType.regist(self).embedding(:namespaces,
                                           :flows,
                                           :connection_roles,
                                           :translators,
                                           :events,
                                           :applications,
                                           :data_types,
                                           :schemas,
                                           :custom_validators,
                                           :algorithms,
                                           :webhooks,
                                           :connections,
                                           :authorizations,
                                           :oauth_providers,
                                           :oauth_clients,
                                           :oauth2_scopes).excluding(:image)

    mount_uploader :image, AccountImageUploader

    field :readme, type: String

    NO_DATA_FIELDS = %w(name readme)

    has_and_belongs_to_many :namespaces, class_name: Setup::Namespace.to_s, inverse_of: nil

    has_and_belongs_to_many :flows, class_name: Setup::Flow.to_s, inverse_of: nil
    has_and_belongs_to_many :translators, class_name: Setup::Translator.to_s, inverse_of: nil
    has_and_belongs_to_many :events, class_name: Setup::Event.to_s, inverse_of: nil
    has_and_belongs_to_many :algorithms, class_name: Setup::Algorithm.to_s, inverse_of: nil
    has_and_belongs_to_many :applications, class_name: Setup::Application.to_s, inverse_of: nil

    has_and_belongs_to_many :connection_roles, class_name: Setup::ConnectionRole.to_s, inverse_of: nil
    has_and_belongs_to_many :webhooks, class_name: Setup::Webhook.to_s, inverse_of: nil
    has_and_belongs_to_many :connections, class_name: Setup::Connection.to_s, inverse_of: nil

    has_and_belongs_to_many :data_types, class_name: Setup::DataType.to_s, inverse_of: nil
    has_and_belongs_to_many :schemas, class_name: Setup::Schema.to_s, inverse_of: nil
    has_and_belongs_to_many :custom_validators, class_name: Setup::CustomValidator.to_s, inverse_of: nil
    embeds_many :data, class_name: Setup::CollectionData.to_s, inverse_of: :setup_collection

    has_and_belongs_to_many :authorizations, class_name: Setup::Authorization.to_s, inverse_of: nil
    has_and_belongs_to_many :oauth_providers, class_name: Setup::BaseOauthProvider.to_s, inverse_of: nil
    has_and_belongs_to_many :oauth_clients, class_name: Setup::OauthClient.to_s, inverse_of: nil
    has_and_belongs_to_many :oauth2_scopes, class_name: Setup::Oauth2Scope.to_s, inverse_of: nil

    accepts_nested_attributes_for :data, allow_destroy: true

    validates_uniqueness_of :name

    before_save :check_dependencies

    def check_dependencies
      algorithms = Set.new(self.algorithms)
      flows.each do |flow|
        {
          event: events,
          translator: translators,
          webhook: webhooks,
          connection_role: connection_roles,
          response_translator: translators
        }.each do |key, association|
          unless (value = flow.send(key)).nil? || association.any? { |v| v == value }
            association << value
          end
        end
        check_data_type_dependencies(flow.custom_data_type, algorithms)
        check_data_type_dependencies(flow.response_data_type, algorithms)
      end
      connection_roles.each do |connection_role|
        connection_role.webhooks.each { |webhook| webhooks << webhook unless webhooks.any? { |v| v == webhook } }
        connection_role.connections.each { |connection| connections << connection unless connections.any? { |v| v == connection } }
      end
      connections.each do |connection|
        unless (authorization = connection.authorization).nil? || authorizations.any? { |a| a == authorization }
          authorizations << authorization
        end
      end
      authorizations.each do |authorization|
        if authorization.is_a?(Setup::BaseOauthAuthorization)
          {
            provider: :oauth_providers,
            client: :oauth_clients
          }.each do |property, collector_name|
            collector = send(collector_name)
            obj = authorization.send(property)
            collector << obj unless collector.any? { |o| o == obj }
          end
          if authorization.is_a?(Setup::Oauth2Authorization)
            authorization.scopes.each { |scope| oauth2_scopes << scope unless oauth2_scopes.any? { |s| s == scope } }
          end
        end
      end
      translators = Set.new(self.translators)
      self.translators.each do |translator|
        [:source_exporter, :target_importer].each do |key|
          if (t = translator.send(key))
            translators << t
          end
        end
      end
      translators.each do |translator|
        check_data_type_dependencies(translator.source_data_type, algorithms)
        check_data_type_dependencies(translator.target_data_type, algorithms)
      end
      events.each { |event| check_data_type_dependencies(event.data_type, algorithms) if event.is_a?(Setup::Observer) }
      data_types.each { |data_type| check_data_type_dependencies(data_type, algorithms) }
      data.each { |collection_data| check_data_type_dependencies(collection_data.data_type, algorithms) }

      applications.each do |app|
        app.actions.each { |action| algorithms << action.algorithm }
        app.application_parameters.each do |app_parameter|
          if (param_model = app.configuration_model.property_model(app_parameter.name)) &&
            (item = app.configuration[app_parameter.name]) &&
            (association = reflect_on_all_associations(:has_and_belongs_to_many).detect { |r| r.klass == param_model }) &&
            (association = send(association.name)) &&
            !association.include?(item)
            association << item
          end
        end
      end

      visited_algs = Set.new
      algorithms.each { |alg| alg.for_each_call(visited_algs) }
      self.algorithms = visited_algs.to_a

      nss = Set.new
      reflect_on_all_associations(:has_and_belongs_to_many).each do |relation|
        next unless relation.klass.include?(Setup::NamespaceNamed)
        nss += send(relation.name).distinct(:namespace)
      end
      self.namespaces = Setup::Namespace.all.any_in(name: nss.to_a)

      reflect_on_all_associations(:has_and_belongs_to_many).each do |relation|
        next unless relation.klass.include?(CrossOrigin::Document)
        if (shared_objs = (collector = send(relation.name)).where(:origin.nin => [:default])).present?
          shared_objs.each { |obj| collector.delete(obj) }
        end
      end

      errors.blank?
    end

    def empty?
      reflect_on_all_associations(:has_and_belongs_to_many).all? { |relation| send(relation.name).empty? }
    end

    class << self
      def find_by_id(*args)
        where(name: args[0]).first
      end
    end

    private

    def check_data_type_dependencies(data_type, algorithms)
      if data_type
        algorithms.merge(data_type.before_save_callbacks)
        algorithms.merge(data_type.records_methods)
        algorithms.merge(data_type.data_type_methods)
        if data_type.is_a?(Setup::FileDataType)
          check_data_type_dependencies(data_type.schema_data_type, algorithms)
          data_type.validators.each do |validator|
            custom_validators << validator if validator.is_a?(Setup::CustomValidator) && custom_validators.none? { |v| v == validator }
            check_data_type_dependencies(validator.try(:schema_data_type), algorithms)
            if (algorithm = validator.try(:algorithm))
              algorithms << algorithm
            end
          end
        end
      end
    end
  end
end
