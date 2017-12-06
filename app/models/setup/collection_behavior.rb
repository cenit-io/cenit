require 'cenit/cross_tracing_criteria'

module Setup
  module CollectionBehavior
    extend ActiveSupport::Concern

    include CollectionName
    include JsonMetadata

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
        :resources,
        :operations,
        :webhooks,
        :connections,
        :authorizations,
        :oauth_providers,
        :oauth_clients,
        :oauth2_scopes
      ]

    included do
      build_in_data_type.embedding(*COLLECTING_PROPERTIES).excluding(:image)

      field :title, type: String, default: ''
      field :readme, type: String

      has_and_belongs_to_many :namespaces, class_name: Setup::Namespace.to_s, inverse_of: nil

      has_and_belongs_to_many :flows, class_name: Setup::Flow.to_s, inverse_of: nil
      has_and_belongs_to_many :translators, class_name: Setup::Translator.to_s, inverse_of: nil
      has_and_belongs_to_many :events, class_name: Setup::Event.to_s, inverse_of: nil
      has_and_belongs_to_many :algorithms, class_name: Setup::Algorithm.to_s, inverse_of: nil
      has_and_belongs_to_many :applications, class_name: Setup::Application.to_s, inverse_of: nil
      has_and_belongs_to_many :snippets, class_name: Setup::Snippet.to_s, inverse_of: nil

      has_and_belongs_to_many :connection_roles, class_name: Setup::ConnectionRole.to_s, inverse_of: nil
      has_and_belongs_to_many :resources, class_name: Setup::Resource.to_s, inverse_of: nil
      has_and_belongs_to_many :operations, class_name: Setup::Operation.to_s, inverse_of: nil
      has_and_belongs_to_many :webhooks, class_name: Setup::PlainWebhook.to_s, inverse_of: nil
      has_and_belongs_to_many :connections, class_name: Setup::Connection.to_s, inverse_of: nil

      has_and_belongs_to_many :data_types, class_name: Setup::DataType.to_s, inverse_of: nil
      has_and_belongs_to_many :schemas, class_name: Setup::Schema.to_s, inverse_of: nil
      has_and_belongs_to_many :custom_validators, class_name: Setup::CustomValidator.to_s, inverse_of: nil

      has_and_belongs_to_many :authorizations, class_name: Setup::Authorization.to_s, inverse_of: nil
      has_and_belongs_to_many :oauth_providers, class_name: Setup::BaseOauthProvider.to_s, inverse_of: nil
      has_and_belongs_to_many :oauth_clients, class_name: Setup::RemoteOauthClient.to_s, inverse_of: nil
      has_and_belongs_to_many :oauth2_scopes, class_name: Setup::Oauth2Scope.to_s, inverse_of: nil

      before_save :make_title, :add_dependencies

      after_initialize { @add_dependencies = true }

      field :warnings, type: Array
    end

    def make_title
      self.title = name.to_title if title.blank?
      errors.blank?
    end

    NO_DATA_FIELDS = %w(title name readme warnings)

    def collecting_data
      hash = {}
      COLLECTING_PROPERTIES.each do |property|
        if (items = send(property).collect(&:share_hash)).present?
          hash[property] = items
        end
      end
      hash[:metadata] = metadata
      hash
    end

    def add_dependencies
      return true unless @add_dependencies
      self.warnings = []
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
          next unless (param_model = app.configuration_model.property_model(app_parameter.name)) &&
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
      if (transformations_relation = collecting_models[Setup::Translator])
        pending = []
        processed = Set.new
        translators.each do |transformation|
          next unless transformation.is_a?(Setup::Converter) && transformation.style == 'mapping'
          pending << transformation
        end
        until pending.empty?
          processed << (converter = pending.pop)
          converter.map_model.associations.each do |name, _|
            next unless (t = converter.mapping.send(name)) && (t = t.transformation)
            if scan_dependencies_on(t,
                                    collecting_models: collecting_models,
                                    dependencies: dependencies,
                                    visited: visited)
              dependencies[transformations_relation.name] << t
              if processed.exclude?(t) &&
                t.is_a?(Setup::Converter) &&
                t.style == 'mapping'
                pending << t
              end
            end
          end
        end
      end
      params = {}
      if (data_types = dependencies[:data_types])
        data_types = data_types.to_a
        while (data_type = data_types.pop)
          data_type.each_ref(params) do |dt|
            next unless scan_dependencies_on(dt,
                                             collecting_models: collecting_models,
                                             dependencies: dependencies,
                                             visited: visited)
            dependencies[:data_types] << dt
            data_types << dt
          end if data_type.is_a?(Setup::JsonDataType)
        end
      end
      if (not_found_refs = params[:not_found]).present?
        self.warnings += not_found_refs.to_a.collect { |ref| "Reference not found #{ref.to_json}" }
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

      collecting_models.each do |model, relation|
        reference_keys = (model.data_type.get_referenced_by || []) - %w(_id)
        send(relation.name).group_by do |record|
          reference_keys.collect { |key| record.try(key) }.compact
        end.each do |keys, records|
          next unless records.length > 1
          keys_hash = {}
          reference_keys.each_with_index { |key, index| keys_hash[key] = keys[index] }
          self.warnings << "Multiple #{relation.name} with the same reference keys #{keys_hash.to_json}"
        end
      end

      errors.blank?
    end

    def empty?
      COLLECTING_PROPERTIES.all? { |property| send(property).empty? }
    end

    def cross(origin = :default)
      cross_to(origin)
      if (super_method = method(__method__).super_method)
        super_method.call(origin)
      end
    end

    def cross_to(origin = :default, criteria = {})
      COLLECTING_PROPERTIES.each do |property|
        r = reflect_on_association(property)
        next unless (model = r.klass).include?(Setup::CrossOriginShared)
        model.where(:id.in => send(r.foreign_key)).and(criteria).with_tracing.cross(origin) do |_, non_traced_ids|
          next unless non_traced_ids.present?
          Account.each do |account|
            if account == Account.current
              model.clear_pins_for(account, non_traced_ids)
            else
              model.clear_config_for(account, non_traced_ids)
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
        dependencies = record.send(relation.name)
        dependencies = [dependencies] unless relation.many?
        dependencies.each do |dependency|
          next unless dependency
          collecting_relation = opts[:collecting_models]
          collecting_relation = collecting_relation[collecting_relation.keys.detect { |model| model >= dependency.class }]
          association = collecting_relation && opts[:dependencies][collecting_relation.name]
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
