module Setup
  class SchemasImport < Setup::Task
    include Setup::DataUploader
    include Setup::DataIterator
    include RailsAdmin::Models::Setup::SchemasImportAdmin

    build_in_data_type

    field :namespace, type: String
    field :base_uri, type: String, default: ''

    before_save do
      self.namespace = message[:namespace] if namespace.blank?
      self.base_uri = message[:base_uri].to_s
    end

    def decompress_content?
      (i = (name = data.path).rindex('.')) && name.from(i) == '.zip'
    end

    def run(message)
      schemas = {}
      saved_schemas_ids = []
      each_entry do |entry_name, schema|
        uri = base_uri.blank? ? entry_name : "#{base_uri}/#{entry_name}"
        schemas[entry_name] = Setup::Schema.new(namespace: namespace, uri: uri, schema: schema)
      end
      new_schemas_attributes = []
      schemas.each do |entry_name, schema|
        schema.validates_before
        if schema.validates_configuration
          saved_schemas_ids << schema.id
          new_schemas_attributes << schema.attributes
        else
          fail "Schemas data contains invalid schema #{entry_name}: #{schema.errors.full_messages.join(', ')}"
        end
      end
      begin
        Setup::Schema.collection.insert_many(new_schemas_attributes)
      rescue Exception => ex
        fail "Schemas could not be saved: #{ex.message}"
      end if new_schemas_attributes.present?
    rescue Exception => ex
      Setup::Schema.where(:id.in => saved_schemas_ids).delete_all if saved_schemas_ids.present?
      raise ex
    end
  end
end
