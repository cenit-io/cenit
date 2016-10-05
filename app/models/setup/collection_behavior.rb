module Setup
  module CollectionBehavior
    extend ActiveSupport::Concern

    include CollectionName

    COLLECTING_PROPERTIES =
      [
        :namespaces,
        :flows,
        :connection_roles,
        :translators,
        :events,
        :applications,
        :data_types,
        :schemas,
        :custom_validators,
        :algorithms,
        :snippets,
        :webhooks,
        :connections,
        :authorizations,
        :oauth_providers,
        :oauth_clients,
        :oauth2_scopes
      ]

    included do

      build_in_data_type.embedding(*COLLECTING_PROPERTIES).excluding(:image)

      field :title
      field :readme, type: String

      has_and_belongs_to_many :namespaces, class_name: Setup::Namespace.to_s, inverse_of: nil

      has_and_belongs_to_many :flows, class_name: Setup::Flow.to_s, inverse_of: nil
      has_and_belongs_to_many :translators, class_name: Setup::Translator.to_s, inverse_of: nil
      has_and_belongs_to_many :events, class_name: Setup::Event.to_s, inverse_of: nil
      has_and_belongs_to_many :algorithms, class_name: Setup::Algorithm.to_s, inverse_of: nil
      has_and_belongs_to_many :applications, class_name: Setup::Application.to_s, inverse_of: nil
      has_and_belongs_to_many :snippets, class_name: Setup::Snippet.to_s, inverse_of: nil

      has_and_belongs_to_many :connection_roles, class_name: Setup::ConnectionRole.to_s, inverse_of: nil
      has_and_belongs_to_many :webhooks, class_name: Setup::Webhook.to_s, inverse_of: nil
      has_and_belongs_to_many :connections, class_name: Setup::Connection.to_s, inverse_of: nil

      has_and_belongs_to_many :data_types, class_name: Setup::DataType.to_s, inverse_of: nil
      has_and_belongs_to_many :schemas, class_name: Setup::Schema.to_s, inverse_of: nil
      has_and_belongs_to_many :custom_validators, class_name: Setup::CustomValidator.to_s, inverse_of: nil

      has_and_belongs_to_many :authorizations, class_name: Setup::Authorization.to_s, inverse_of: nil
      has_and_belongs_to_many :oauth_providers, class_name: Setup::BaseOauthProvider.to_s, inverse_of: nil
      has_and_belongs_to_many :oauth_clients, class_name: Setup::OauthClient.to_s, inverse_of: nil
      has_and_belongs_to_many :oauth2_scopes, class_name: Setup::Oauth2Scope.to_s, inverse_of: nil

      before_save :add_dependencies

      after_initialize { @add_dependencies = true }

      attr_reader :warnings
    end

    NO_DATA_FIELDS = %w(name readme)

    def collecting_data
      hash = {}
      COLLECTING_PROPERTIES.each do |property|
        if (items = send(property).collect(&:share_hash)).present?
          hash[property] = items
        end
      end
      hash
    end

    def add_dependencies
      return true unless @add_dependencies
      @warnings = nil
      collecting_models = {}
      COLLECTING_PROPERTIES.each do |property|
        relation = reflect_on_association(property)
        collecting_models[relation.klass] = relation
      end
      dependencies = Hash.new { |h, k| h[k] = Set.new }
      visited = Set.new
      COLLECTING_PROPERTIES.each do |property|
        send(property).each do |record|
          dependencies[property] << record if scan_dependencies_on(record,
                                                                   collecting_models: collecting_models,
                                                                   dependencies: dependencies,
                                                                   visited: visited)
        end
      end
      applications.each do |app|
        app.application_parameters.each do |app_parameter|
          if (param_model = app.configuration_model.property_model(app_parameter.name)) &&
            (relation = collecting_models[param_model]) &&
            (items = app.configuration[app_parameter.name])
            items = [items] unless items.is_a?(Enumerable)
            items.each do |item|
              dependencies[relation.name] << item if scan_dependencies_on(item,
                                                                          collecting_models: collecting_models,
                                                                          dependencies: dependencies,
                                                                          visited: visited)
            end
          end
        end
      end
      params = {}
      if (data_types = dependencies[:data_types])
        data_types = data_types.to_a
        while (data_type = data_types.pop)
          data_type.each_ref(params) do |dt|
            if scan_dependencies_on(dt,
                                    collecting_models: collecting_models,
                                    dependencies: dependencies,
                                    visited: visited)
              dependencies[:data_types] << dt
              data_types << dt
            end
          end if data_type.is_a?(Setup::JsonDataType)
        end
      end
      if (not_found_refs = params[:not_found]).present?
        @warnings = not_found_refs.to_a.collect { |ref| "Reference not found #{ref.to_json}" }
      end
      dependencies.each do |property, set|
        set.merge(send(property))
        self.send("#{property}=", set.to_a)
      end
      nss = Set.new
      collecting_models.values.each do |relation|
        next unless relation.klass.include?(Setup::NamespaceNamed)
        nss += send(relation.name).distinct(:namespace).flatten
      end
      self.namespaces = Setup::Namespace.all.any_in(name: nss.to_a)
      namespaces.each { |ns| nss.delete(ns.name) }
      nss.each { |ns| self.namespaces << Setup::Namespace.create(name: ns) }

      errors.blank?
    end

    def empty?
      COLLECTING_PROPERTIES.all? { |property| send(property).empty? }
    end

    def cross(origin)
      COLLECTING_PROPERTIES.each do |property|
        r = reflect_on_association(property)
        if (model = r.klass).include?(Setup::CrossOriginShared)
          model.where(:id.in => send(r.foreign_key)).with_tracking.cross(origin) do |_, non_tracked_ids|
            if non_tracked_ids.present?
              Account.each do |account| #TODO Run as a task in the background
                if account == Account.current
                  model.clear_pins_for(account, non_tracked_ids)
                else
                  model.clear_config_for(account, non_tracked_ids)
                end
              end
            end
          end
        end
      end
    end

    def shared?
      false
    end

    module ClassMethods

      def image_with(uploader)
        mount_uploader :image, uploader
      end

      def unique_name
        validates_uniqueness_of :name
      end

      def find_by_id(*args)
        where(name: args[0]).first
      end
    end

    protected

    def scan_dependencies_on(record, opts)
      return false if opts[:visited].include?(record)
      opts[:visited] << record
      record.class.reflect_on_all_associations(:embeds_one,
                                               :embeds_many,
                                               :has_one,
                                               :belongs_to,
                                               :has_many,
                                               :has_and_belongs_to_many).each do |relation|
        next if [User, Account].include?(relation.klass)
        collecting_relation = opts[:collecting_models][relation.klass]
        association = collecting_relation && opts[:dependencies][collecting_relation.name]
        if relation.many?
          record.send(relation.name).each do |dependency|
            if association && association.exclude?(dependency)
              association << dependency
            end
            scan_dependencies_on(dependency, opts)
          end
        elsif (dependency = record.send(relation.name))
          if association && association.exclude?(dependency)
            association << dependency
          end
          scan_dependencies_on(dependency, opts)
        end
      end
      true
    end
  end
end
