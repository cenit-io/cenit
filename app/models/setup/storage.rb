module Setup
  class Storage
    include CenitUnscoped

    store_in collection: Proc.new { Account.tenant_collection_prefix + '.files' }

    BuildInDataType.regist(self)

    Setup::Models.exclude_actions_for self, :new, :edit, :translator_update, :import, :convert, :delete_all


    field :filename, type: String
    field :contentType, type: String
    field :length, type: Integer

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

    private

    def name_components
      @name_components ||= filename.split('/')
    end

  end
end
