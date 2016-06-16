module Setup
  class Storage
    include CenitUnscoped

    store_in collection: Proc.new { Account.tenant_collection_prefix + '.files' }

    build_in_data_type

    deny :copy, :new, :edit, :translator_update, :import, :convert, :delete_all, :simple_export


    field :filename, type: String
    field :contentType, type: String
    field :length, type: Integer

    before_destroy do
      self.class.chunks_collection.find(files_id: id).delete_many
    end

    def storage_name
      name_components.last
    end

    def storer_name
      name_components.second.gsub('~', '/').camelize
    end

    def storer_model
      storer_name.constantize
    end

    def storer_property
      name_components.third
    end

    def storer_object
      storer_model.where(id: storer_object_id).first
    end

    def storer_object_id
      name_components.fourth
    end

    def label
      "#{storer_property.capitalize} on #{storer_name}"
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
