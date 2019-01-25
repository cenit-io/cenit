module Setup
  class Translator
    include CrossOriginShared
    include NamespaceNamed
    include ClassHierarchyAware
    include ::RailsAdmin::Models::Setup::TranslatorAdmin

    abstract_class true

    build_in_data_type.referenced_by(:namespace, :name)

    field :type, type: Symbol, default: -> { self.class.transformation_type }

    before_validation do
      if (type = self.class.transformation_type)
        self.type = type
      end
    end

    before_save :validates_configuration

    def validates_configuration
      errors.add(:type, 'is not valid') unless self.class.type_enum.include?(type)
      errors.blank?
    end

    def data_type
      fail NotImplementedError
    end

    def execute(options)
      fail NotImplementedError
    end

    def run(options = {})
      execution_options = build_execution_options(options)
      before_execute(execution_options)
      execution_options[:result] = execute(execution_options)
      after_execute(execution_options)
      execution_options[:result]
    end

    def base_execution_options(options)
      opts = {}
      #TODO Remove translator options after complete translators migration
      opts[:transformation] = opts[:translator] = self
      opts
    end

    def build_execution_options(options)
      options[:data_type] ||= data_type
      execution_options = base_execution_options(options)
      self.class.fields.keys.each { |key| execution_options[key.to_sym] = send(key) }
      self.class.relations.keys.each { |key| execution_options[key.to_sym] = send(key) }
      execution_options.merge!(options) { |_, context_val, options_val| !context_val ? options_val : context_val }
      execution_options[:options] ||= {}
      execution_options
    end

    def before_execute(options)
      if (dt = data_type)
        dt.regist_creation_listener(self)
      end
    end

    def after_execute(options)
      if (dt = data_type)
        dt.unregist_creation_listener(self)
      end
    end

    def before_create(record)
      true #Handle in subclasses
    end

    class << self

      def type_enum
        [:Import, :Export, :Update, :Conversion]
      end

      def transformation_type(*args)
        if args.length > 0
          @transformation_type = args[0].to_s.to_sym
        end
        @transformation_type || (superclass < Translator ? superclass.transformation_type : nil)
      end
    end
  end
end
