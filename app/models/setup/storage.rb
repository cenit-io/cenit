module Setup
  class Storage
    include CenitUnscoped

    store_in collection: proc { Account.tenant_collection_prefix + '.files' }

    build_in_data_type.and(properties: {
      storer_data_type: {
        referenced: true,
        '$ref': {
          namespace: 'Setup',
          name: 'DataType'
        },
        edi: {
          discard: true
        },
        virtual: true
      },
      storer_object: {
        type: 'object',
        virtual: true
      },
      storer_property: {
        type: 'string',
        virtual: true
      }
    })

    deny :create, :update


    field :filename, type: String
    field :contentType, type: String
    field :length, type: Integer
    field :metadata

    after_destroy { chunks.delete_many }

    def identifier
      filename
    end

    def content_type
      contentType
    end

    def chunks
      self.class.chunks_collection.find(files_id: id)
    end

    def read
      data = ''
      hash = {}
      c = 0
      chunks.each do |chunk|
        n = chunk['n']
        if n == c
          data += chunk['data'].data
          c += 1
        else
          hash[n] = chunk['data'].data
        end
      end
      hash.keys.sort.each { |n| data += hash[n] }
      data
    end

    def storage_name
      name_components.last
    end

    def storer_name
      (name = name_components.second) && name.tr('~', '/').camelize
    end

    def storer_model
      (name = storer_name) && name.constantize
    end

    def storer_data_type
      storer_model&.data_type
    rescue
      nil
    end

    def storer_property
      name_components.third
    end

    def storer_object
      (model = storer_model) && model.where(id: storer_object_id).first
    end

    def storer_object_id
      name_components.fourth
    end

    def label
      property = storer_property || '<unknown property>'
      storer = storer_name || '<unknown storer>'
      "#{property.capitalize} on #{storer}"
    end

    class << self

      def chunks_collection
        Mongoid.default_client[(Account.tenant_collection_prefix + '.chunks').to_sym]
      end

      def clean_up
        collection.drop
        chunks_collection.drop
      end
    end

    private

    def name_components
      @name_components ||= filename.split('/')
    end

  end
end
