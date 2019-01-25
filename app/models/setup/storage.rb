module Setup
  class Storage
    include CenitUnscoped
    include ::RailsAdmin::Models::Setup::StorageAdmin

    store_in collection: proc { Account.tenant_collection_prefix + '.files' }

    build_in_data_type

    deny :copy, :new, :edit, :translator_update, :import, :convert, :delete_all, :simple_export


    field :filename, type: String
    field :contentType, type: String
    field :length, type: Integer
    field :metadata

    after_destroy { self.class.chunks_collection.find(files_id: id).delete_many }

    def storage_name
      name_components.last
    end

    def storer_name
      (name = name_components.second) && name.tr('~', '/').camelize
    end

    def storer_model
      (name = storer_name) && name.constantize
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
