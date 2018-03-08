module Setup
  class ConverterTransformation < Translator
    include RailsAdmin::Models::Setup::ConverterTransformationAdmin

    abstract_class true

    transformation_type :Conversion

    belongs_to :source_data_type, class_name: Setup::DataType.to_s, inverse_of: nil
    belongs_to :target_data_type, class_name: Setup::DataType.to_s, inverse_of: nil

    field :discard_events, type: Boolean

    validates_presence_of :source_data_type

    def data_type
      source_data_type
    end

    #TODO Remove this method if refactored Conversions does not use it
    def apply_to_source?(data_type)
      source_data_type.blank? || source_data_type == data_type
    end

    #TODO Remove this method if refactored Conversions does not use it
    def apply_to_target?(data_type)
      target_data_type.blank? || target_data_type == data_type
    end

    def before_create(record)
      record.instance_variable_set(:@discard_event_lookup, true) if discard_events
      super
    end

    def after_execute(options)
      super
      return unless (target = options[:target])
      if !options.key?(:save_result) || options[:save_result]
        target.instance_variable_set(:@discard_event_lookup, options[:discard_events])
        unless Cenit::Utility.save(target)
          fail PersistenceException.new(target)
        end
      end
      options[:result] = target
    end
  end
end
