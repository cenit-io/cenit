module Mongoff
  module GridFs

    class FileModel < Mongoff::Model

      MINIMUM_CHUNK_SIZE = 2 ** 18

      SCHEMA = Cenit::Utility.stringfy({
                                         type: :object,
                                         properties:
                                           {
                                             length: {
                                               title: 'Size',
                                               type: :integer
                                             },
                                             chunkSize: {
                                               type: :integer,
                                               minimum: MINIMUM_CHUNK_SIZE,
                                               default: MINIMUM_CHUNK_SIZE
                                             },
                                             uploadDate: {
                                               title: 'Uploaded at',
                                               type: :string,
                                               format: :time
                                             },
                                             md5: {
                                               type: :string
                                             },

                                             filename: {
                                               title: 'File name',
                                               type: :string
                                             },
                                             contentType: {
                                               title: 'Content type',
                                               type: :string,
                                               default: 'application/octet-stream'
                                             },
                                             aliases: {
                                               type: :array,
                                               items: {
                                                 type: :string
                                               }
                                             },
                                             metadata: {},
                                           }
                                       })

      attr_reader :chunk_model

      def record_class
        Mongoff::GridFs::File
      end

      protected

      def initialize(data_type, options = {})
        super
        @chunk_model = ChunkModel.new(self)
      end
    end
  end
end