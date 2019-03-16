module Setup
  module BulkableTask
    extend ActiveSupport::Concern

    protected

    def object_ids_from(message)
      message[:object_ids] || message[:bulk_ids]
    end

    def objects_from(message)
      model = data_type_from(message).records_model
      if (object_ids = object_ids_from(message)).present?
        model.any_in(id: object_ids)
      else
        model.all
      end
    end

    attr_reader :data_type

    def data_type_from(message)
      @data_type =
        if (data_type_id = message['data_type_id'])
          data_type = Setup::BuildInDataType.build_ins[data_type_id] || Setup::DataType.where(id: data_type_id).first
          data_type || fail("Data type with id #{data_type_id} not found")
        else
          fail 'Invalid message: data type ID is missing'
        end
    end
  end
end
