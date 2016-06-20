module Setup
  class DataType
    include SharedEditable
    include NamespaceNamed
    include SchemaHandler
    include DataTypeParser
    include CustomTitle
    include Mongoff::DataTypeMethods
    include ClassHierarchyAware

    abstract_class true

    build_in_data_type.with(:title, :name, :before_save_callbacks, :records_methods, :data_type_methods).referenced_by(:namespace, :name).including(:slug)

    deny :update, :bulk_delete, :delete, :delete_all

    shared_deny :delete, :simple_delete_data_type, :bulk_delete_data_type, :simple_expand, :bulk_expand

    field :title, type: String

    has_and_belongs_to_many :before_save_callbacks, class_name: Setup::Algorithm.to_s, inverse_of: nil
    has_and_belongs_to_many :records_methods, class_name: Setup::Algorithm.to_s, inverse_of: nil
    has_and_belongs_to_many :data_type_methods, class_name: Setup::Algorithm.to_s, inverse_of: nil

    attr_readonly :name

    validates_presence_of :namespace

    before_save :validates_configuration

    after_save :configure

    after_destroy do
      data_type_config.destroy
      clean_up
    end

    def configure
      data_type_config.save
    end

    def validates_configuration
      invalid_algorithms = []
      before_save_callbacks.each { |algorithm| invalid_algorithms << algorithm unless algorithm.parameters.count == 1 }
      if invalid_algorithms.present?
        errors.add(:before_save_callbacks, "algorithms should receive just one parameter: #{invalid_algorithms.collect(&:custom_title).to_sentence}")
      end
      [:records_methods, :data_type_methods].each do |methods|
        by_name = Hash.new { |h, k| h[k] = 0 }
        send(methods).each do |method|
          by_name[method.name] += 1
          if method.parameters.count == 0
            errors.add(methods, "contains algorithm taking no parameter: #{method.custom_title} (at less one parameter is required)")
          end
        end
        if (duplicated_names = by_name.select { |_, count| count > 1 }.keys).present?
          errors.add(methods, "contains algorithms with the same name: #{duplicated_names.to_sentence}")
        end
      end
      unless data_type_config.validate_slug
        data_type_config.errors.messages[:slug].each { |error| errors.add(:slug, error) }
      end
      errors.blank?
    end

    def clean_up
      all_data_type_collections_names.each { |name| Mongoid.default_client[name.to_sym].drop }
    end

    def subtype?
      false
    end

    def data_type_storage_collection_name
      Account.tenant_collection_name(data_type_name)
    end

    def data_type_collection_name
      data_type_storage_collection_name
    end

    def all_data_type_collections_names
      all_data_type_storage_collections_names
    end

    def all_data_type_storage_collections_names
      [data_type_storage_collection_name]
    end

    def storage_size(scale=1)
      records_model.storage_size(scale)
    end

    def count
      records_model.count
    end

    def records_model
      (m = model) && m.is_a?(Class) ? m : @mongoff_model ||= create_mongoff_model
    end

    def model
      data_type_name.constantize rescue nil
    end

    def data_type_name
      "Dt#{self.id.to_s}"
    end

    def create_default_events
      if records_model.persistable? && Setup::Observer.where(data_type: self).empty?
        Setup::Observer.create(data_type: self, triggers: '{"created_at":{"0":{"o":"_not_null","v":["","",""]}}}')
        Setup::Observer.create(data_type: self, triggers: '{"updated_at":{"0":{"o":"_presence_change","v":["","",""]}}}')
      end
    end

    def find_data_type(ref, ns = namespace)
      super ||
        Setup::DataType.where(namespace: ns, name: ref).first ||
        ((ref = ref.to_s).start_with?('Dt') && Setup::DataType.where(id: ref.from(2)).first) ||
        nil
    end

    def method_missing(symbol, *args)
      if (method = data_type_methods.detect { |alg| alg.name == symbol.to_s })
        args.unshift(self)
        method.reload
        method.run(args)
      else
        super
      end
    end

    class << self

      def where(expression)
        if expression.is_a?(Hash) && Setup::DataTypeConfig::FIELDS.any? { |field| expression.has_key?(field.to_sym) || expression.has_key?(field) }
          config_options = {}
          Setup::DataTypeConfig::FIELDS.each do |field|
            if expression.has_key?(key = field.to_sym) || expression.has_key?(key = field)
              config_options[field] = expression.delete(key)
            end
          end
          super.any_in(id: Setup::DataTypeConfig.where(config_options).collect(&:data_type_id))
        else
          super
        end
      end

      def for_name(name)
        where(id: name.from(2)).first
      end
    end

    after_initialize { Setup::DataTypeConfig::FIELDS.each { |field| attributes.delete(field) } } #TODO Remove after DB migration

    def data_type_config
      @data_type_config ||=
        begin
          if new_record?
            Setup::DataTypeConfig.new(data_type: self)
          else
            Setup::DataTypeConfig.find_or_create_by(data_type: self)
          end
        end
    end

    delegate *Setup::DataTypeConfig::FIELDS.collect { |p| [p.to_sym, "#{p}=".to_sym] }.flatten, to: :data_type_config

    protected

    def mongoff_model_class
      Mongoff::Model
    end

    def create_mongoff_model
      mongoff_model_class.for(data_type: self)
    end
  end
end