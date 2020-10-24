module Setup
  class Namespace
    include CenitScoped
    include Slug

    build_in_data_type.referenced_by(:name)

    field :name, type: String

    before_validation do
      self.name =
        if name.nil?
          ''
        else
          name.strip
        end.strip
    end

    after_save do
      if (old_name = changed_attributes['name'])
        #TODO Refactor namespace name on setup models
      end
    end

    validates_uniqueness_of :name

    def set_schemas_scope(schemas)
      @schemas_scope = {}
      schemas.each { |schema| @schemas_scope[schema.uri] = schema }
    end

    def schema_for(base_uri, relative_uri)
      uri = Setup::Schema.abs_uri(base_uri, relative_uri)
      if (schema = @schemas_scope[uri])
        schema
      else
        Setup::Schema.where(namespace: name, uri: uri).first
      end
    end

    def method_missing(symbol, *args)
      if (relation_name = Setup::Collection::COLLECTING_PROPERTIES.detect { |name| name.to_s.singularize == symbol.to_s })
        Setup::Collection.reflect_on_association(relation_name).klass.where(namespace: name, name: args[0].to_s).first
      else
        super
      end
    end

    def respond_to?(*args)
      super || Setup::Collection::COLLECTING_PROPERTIES.any? { |name| name.to_s.singularize == args.first.to_s }
    end

  end
end
