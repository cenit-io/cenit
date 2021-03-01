module Mongoff
  module GridFs
    class FileModel < Mongoff::Model

      MINIMUM_CHUNK_SIZE = 2 ** 18
      MAXIMUM_CHUNK_SIZE = 15 * 2 ** 20

      SCHEMA = Cenit::Utility.stringfy({
                                         type: :object,
                                         label: '{{filename}}',
                                         properties:
                                           {
                                             _id: {
                                               unique: true,
                                               title: 'Id',
                                               description: 'Required',
                                               edi: {
                                                 segment: 'id'
                                               }
                                             },
                                             filename: {
                                               title: 'File name',
                                               type: :string
                                             },
                                             contentType: {
                                               title: 'Content type',
                                               type: :string
                                             },
                                             length: {
                                               title: 'Size',
                                               type: :integer
                                             },
                                             uploadDate: {
                                               title: 'Uploaded at',
                                               type: :string,
                                               format: :'date-time'
                                             },

                                             chunkSize: {
                                               type: :integer,
                                               minimum: MINIMUM_CHUNK_SIZE,
                                               maximum: MAXIMUM_CHUNK_SIZE,
                                               default: MAXIMUM_CHUNK_SIZE,
                                               edi: {
                                                 discard: true
                                               }
                                             },
                                             md5: {
                                               type: :string
                                             },
                                             aliases: {
                                               type: :array,
                                               items: {
                                                 type: :string
                                               }
                                             },
                                             metadata: {},
                                             data: {},
                                             encoding: {
                                               type: :string,
                                               enum: %w(encode64 strict_encode64 urlsafe_encode64)
                                             },
                                             public_url: {
                                               type: :string
                                             }
                                           },
                                         required: %w(filename contentType length)
                                       })

      attr_reader :chunk_model

      def record_class
        Mongoff::GridFs::File
      end

      def stored_properties_on(record)
        p = super
        if data_type.public_read
          p << 'public_url'
        end
        p
      end

      def type_polymorphic?
        false
      end

      protected

      def initialize(data_type, options = {})
        super
        @chunk_model = ChunkModel.new(self)
      end
    end
  end
end