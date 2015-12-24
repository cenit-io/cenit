module Setup
  class SchemasImport < Setup::Task
    include Setup::DataUploader

    BuildInDataType.regist(self)

    Setup::Models.exclude_actions_for self, :new, :edit, :translator_update, :import, :convert, :delete_all

    belongs_to :library, class_name: Setup::Library.to_s, inverse_of: nil
    field :base_uri, type: String, default: ''

    before_save do
      self.library = Setup::Library.where(id: message[:library_id]).first if library.blank?
      self.base_uri = message[:base_uri].to_s
    end

    def run(message)
      errors = []
      schemas = {}
      saved_schemas_ids = []
      if (i = (name = data.path).rindex('.')) && name.from(i) == '.zip'
        begin
          Zip::InputStream.open(StringIO.new(data.read)) do |zis|
            while errors.blank? && entry = zis.get_next_entry
              if (schema = entry.get_input_stream.read).present?
                uri = base_uri.blank? ? entry.name : "#{base_uri}/#{entry.name}"
                schemas[entry.name] = Setup::Schema.new(library: library, uri: uri, schema: schema)
              end
            end
          end
        rescue Exception => ex
          errors << "Zip file format error: #{ex.message}"
        end
      else
        uri = base_uri.blank? ? data.path.split('/').last : base_uri
        schemas[uri] = Setup::Schema.new(library: library, uri: uri, schema: data.read)
      end
      new_schemas_attributes = []
      schemas.each do |entry_name, schema|
        next unless errors.blank?
        schema.prepare_configuration
        if schema.validates_configuration
          saved_schemas_ids << schema.id
          new_schemas_attributes << schema.attributes
        else
          errors << "Schemas data contains invalid schema #{entry_name}: #{schema.errors.full_messages.join(', ')}"
        end
      end
      begin
        Setup::Schema.collection.insert_many(new_schemas_attributes)
      rescue Exception => ex
        errors << "Schemas could not be saved: #{ex.message}"
      end if errors.blank? && new_schemas_attributes.present?
      unless errors.blank?
        Setup::Schema.all.any_in(id: saved_schemas_ids).delete_all
        fail errors.to_sentence
      end
    end
  end
end
