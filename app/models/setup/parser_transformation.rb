module Setup
  class ParserTransformation < Translator
    include RailsAdmin::Models::Setup::ParserTransformationAdmin

    abstract_class true

    transformation_type :Import

    belongs_to :target_data_type, class_name: Setup::DataType.to_s, inverse_of: nil

    field :discard_events, type: Boolean

    def validates_configuration
      remove_attribute(:discard_events) unless discard_events
      super
    end

    def data_type
      target_data_type
    end

    #TODO Remove this method if refactored Conversions does not use it
    def apply_to_target?(data_type)
      target_data_type.blank? || target_data_type == data_type
    end

    def before_create(record)
      record.instance_variable_set(:@discard_event_lookup, true) if discard_events
      true
    end
  end
end
