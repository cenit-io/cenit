module Setup
  class ConverterTransformation < Translator
    include TargetHandlerTransformation
    include DiscardEventsOption
    include ::RailsAdmin::Models::Setup::ConverterTransformationAdmin

    build_in_data_type.referenced_by(:namespace, :name)

    abstract_class true

    transformation_type :Conversion

    belongs_to :source_data_type, class_name: Setup::DataType.to_s, inverse_of: nil
    belongs_to :target_data_type, class_name: Setup::DataType.to_s, inverse_of: nil

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
  end
end
