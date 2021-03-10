module Setup
  module BuildInFileType
    extend ActiveSupport::Concern

    include CenitScoped
    include Mongoff::GridFs::FileStuff

    included do
      store_in collection: proc { data_type.data_type_storage_collection_name }

      field :filename, type: String
      field :contentType, type: String
      field :length, type: Integer
      field :metadata, type: Hash
      field :uploadDate, type: DateTime
      field :chunkSize, type: Integer, default: Mongoff::GridFs::FileModel::MINIMUM_CHUNK_SIZE
      field :md5, type: String
      field :aliases, type: Array

      validates_with Validator

      def orm_model
        self.class
      end

      def save(options)
        insert_or_update_file_stuff(options) &&
          super
      end

      def destroy(options = {})
        if (destroyed = super)
          destroy_file_stuff
        end
        destroyed
      end

      BuildInFileType.regist(self)
    end

    module ClassMethods
      include SchemaHandler

      def data_type
        unless @data_type
          namespace = to_s.split('::')
          name = namespace.pop
          namespace = namespace.join('::')
          @data_type = Setup::FileDataType.find_or_create_by!(
            namespace: namespace,
            name: name,
            origin: :cenit
          )
          @data_type.instance_variable_set(:@file_store_cache_disabled, true)
        end
        @data_type
      end

      def data_type_id
        data_type&.id
      end

      def chunk_model
        data_type.mongoff_model.chunk_model
      end

      def schema
        data_type.schema
      end

      def stored_properties_on(file)
        p = super
        if data_type.public_read
          p << 'public_url'
        end
        p
      end

      def public_by_default(*args)
        if args.length == 0
          @public_by_default
        else
          @public_by_default = args[0]
        end
      end
    end

    class << self

      def [](ref)
        build_ins[ref.to_s]
      end

      def build_ins
        @build_ins ||= {}
      end

      def each(&block)
        build_ins.values.each(&block)
      end

      def regist(model)
        fail "Build-in file type already registered for #{model}" if build_ins.key?(model.to_s)
        model.include(Mongoff::GridFs::FileStuff)
        model.include(self)
        build_ins[model.to_s] = model
      end

      def init!
        build_ins.values.each(&:data_type)
      end
    end

    class Validator < ActiveModel::Validator
      def validate(record)
        record.validate_file_stuff
      end
    end
  end
end
