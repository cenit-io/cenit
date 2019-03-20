module Mongoff
  module GridFs
    class ChunkModel < Model

      SCHEMA = Cenit::Utility.stringfy({
                                         type: :object,
                                         properties:
                                           {
                                             files: {referenced: true}.merge(FileModel::SCHEMA),
                                             n: {type: :integer},
                                             data: {},
                                           }
                                       })

      attr_reader :file_model

      def initialize(file_model)
        super(file_model.data_type, cache: true)
        @mongo_types[:data] = BSON::Binary
        @file_model = file_model
      end

      def collection_name
        data_type.chunks_storage_collection_name
      end

      def property_model(property)
        return file_model if property.to_s == 'files'
        super
      end

      def new(files_id)
        (chunk = super()).document[:files_id] = files_id
        chunk
      end

      def reflectable?
        false
      end

      protected

      def proto_schema
        SCHEMA
      end
    end
  end
end