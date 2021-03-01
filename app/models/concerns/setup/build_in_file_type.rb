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
      field :chunkSize, type: Integer
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

      def destroy(options)
        if (destroyed = super)
          destroy_file_stuff(options)
        end
        destroyed
      end

      BuildInFileType.regist(self)
    end

    module ClassMethods
      include SchemaHandler

      def data_type
        @data_type ||=
          begin
            namespace = to_s.split('::')
            name = namespace.pop
            namespace = namespace.join('::')
            Setup::FileDataType.find_or_create_by!(
              namespace: namespace,
              name: name,
              origin: :cenit
            )
          end
      end

      def schema
        data_type.schema
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
