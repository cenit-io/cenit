module Setup
  class Namespace
    include CenitScoped
    include Slug

    # Setup::Models.exclude_actions_for self, :delete, :bulk_delete, :delete_all

    BuildInDataType.regist(self).referenced_by(:name)

    field :name, type: String

    before_validation do
      self.name =
        if name.nil?
          ''
        else
          name.strip
        end.strip
    end

    validates_uniqueness_of :name

    def set_schemas_scope(schemas)
      @schemas_scope = {}
      schemas.each { |schema| @schemas_scope[schema.uri] = schema }
    end

    def schema_for(base_uri, relative_uri)
      uri = Cenit::Utility.abs_uri(base_uri, relative_uri)
      if (schema = @schemas_scope[uri])
        schema
      else
        schemas.where(namespace: name, uri: uri).first
      end
    end
  end
end
