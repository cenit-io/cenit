module Setup
  class SchemasImport < Setup::Task
    include Setup::DataUploader
    include Setup::DataIterator
    include ::RailsAdmin::Models::Setup::SchemasImportAdmin

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

    def run(_message)
      each_entry do |entry_name, schema|
        uri = base_uri.blank? ? entry_name : "#{base_uri}/#{entry_name}"
        schema = Setup::Schema.create(namespace: namespace, uri: uri, schema: schema)
        fail schema.errors.full_messages.to_sentence unless schema.errors.blank?
      end
    end

  end
end
