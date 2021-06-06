module Setup
  class UpdaterTransformation < Translator
    include TargetHandlerTransformation
    include DiscardEventsOption

    build_in_data_type.referenced_by(:namespace, :name)

    abstract_class true

    transformation_type :Update

    belongs_to :target_data_type, class_name: Setup::DataType.to_s, inverse_of: nil

    def data_type
      target_data_type
    end

    #TODO Remove this method if refactored Conversions does not use it
    def apply_to_target?(data_type)
      target_data_type.blank? || target_data_type == data_type
    end
  end
end
