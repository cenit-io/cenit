module Setup
  class Notification
    include CenitScoped
    include NamespaceNamed
    include CustomTitle
    include ClassHierarchyAware
    include ReqRejValidator

    abstract_class true

    belongs_to :data_type, class_name: Setup::DataType.name, inverse_of: nil
    has_and_belongs_to_many :observers, class_name: Setup::Observer.name, inverse_of: nil
    belongs_to :transformation, class_name: Setup::Translator.name, inverse_of: nil

    field :active, type: Boolean

    before_save :ready_to_save!, :validates_configuration

    # Virtual abstract method to process a data type record.
    def process(record)
      fail NotImplementedError
    end

    def ready_to_save!
      throw(:abort) unless ready_to_save?
    end

    def ready_to_save?
      !data_type.nil?
    end

    def validates_configuration
      unless requires :data_type, :observers, :transformation
        unless self.class.transformation_types.include?(transformation.class)
          errors.add(:transformation, "type is not valid, #{self.class.transformation_types.collect(&:to_s).to_sentence(last_word_connector: ' or ')} expected")
        end
        errors.add(:transformation, 'data type mismatch') unless transformation.data_type.nil? || data_type == transformation.data_type
      end
      abort_if_has_errors
    end

    class << self
      def transformation_types(*args)
        if args.length.positive?
          @transformation_types = args.flatten
        else
          @transformation_types || (superclass.is_a?(Setup::Notification) ? superclass.transformation_types : [])
        end
      end
    end
  end
end