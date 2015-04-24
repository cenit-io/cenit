module Setup
  class Schema
    include CenitScoped

    Setup::Models.exclude_actions_for self, :bulk_delete, :delete, :delete_all

    BuildInDataType.regist(self).with(:uri, :schema).including(:library).referenced_by(:library, :uri)

    belongs_to :library, class_name: Setup::Library.to_s, inverse_of: :schemas

    field :uri, type: String
    field :schema, type: String

    has_many :data_types, class_name: Setup::Model.to_s, inverse_of: :schema, dependent: :destroy

    field :schema_type, type: Symbol

    attr_readonly :library, :uri

    validates_presence_of :library, :uri, :schema

    before_save :save_data_types
    after_save :load_models
    before_destroy :destroy_data_types

    def load_models(options = {})
      unless @data_types_to_reload
        reload
        @data_types_to_reload = data_types.activated
      end
      models = Set.new
      @data_types_to_reload.each do |data_type|
        data_type.reload
        models += data_type.load_models(options)[:loaded] if data_type.activated
      end
      RailsAdmin::AbstractModel.update_model_config(models)
    end

    def include_missing?
      @include_missing
    end

    attr_reader :include_missing_message

    def run_after_initialized
      return true if @_initialized
      @include_missing = false
      @data_types_to_keep = Set.new
      @new_data_types = []
      if self.new_record? && self.library && self.library.schemas.where(uri: self.uri).first
        errors.add(:uri, "is is already taken on library #{self.library.name}")
        return false
      end
      begin
        parse_schemas.each do |name, schema|
          if data_type = data_types.where(name: name).first
            data_type.model_schema = schema.to_json
          elsif library && library.find_data_type_by_name(name)
            errors.add(:schema, "model name #{name} is already taken on library #{library.name}")
          else
            @new_data_types << (data_type = Setup::DataType.new(name: name, model_schema: schema.to_json))
            self.data_types << data_type
          end
          if data_type && data_type.validate_model
            @data_types_to_keep << data_type
          else
            data_type.errors.each do |attribute, error|
              errors.add(:schema, "when defining model #{name} on attribute '#{attribute}': #{error}")
            end if data_type
            destroy_data_types
            return false
          end
        end
        report = Model.shutdown(data_types.activated, report_only: true)
        @data_types_to_reload = report[:destroyed].collect(&:data_type).uniq.select(&:activated)
        Model.shutdown(data_types.activated)
        data_types.each do |data_type|
          unless @data_types_to_keep.include?(data_type)
            data_type.destroy
            @data_types_to_reload.delete(data_type)
          end
        end

      rescue Exception => ex
        #TODO Delete raise
        #raise ex
        if @include_missing = ex.is_a?(Xsd::IncludeMissingException)
          @include_missing_message = ex.message
        end
        puts "ERROR: #{errors.add(:schema, ex.message).to_s}"
        destroy_data_types
        return false
      end
      @_initialized = true
    end

    def cenit_ref_schema
      #TODO !!!
      schema
    end

    private

    def save_data_types
      if run_after_initialized
        puts "Saving data types for #{uri}"
        (@data_types_to_keep && @data_types_to_keep.empty? ? data_types : @data_types_to_keep).each { |data_type| puts data_type.name }
        (@data_types_to_keep && @data_types_to_keep.empty? ? data_types : @data_types_to_keep).each(&:save)
      else
        false
      end
    end

    def destroy_data_types
      @shutdown_report = Model.shutdown(@new_data_types || data_types.activated, destroy: true)
    end

    def parse_schemas
      self.schema = schema.strip
      if schema.start_with?('{') || self.schema.start_with?('[')
        self.schema_type = :json_schema
        parse_json_schema
      else
        self.schema_type = :xml_schema
        parse_xml_schema
      end
    end

    def parse_json_schema
      json = JSON.parse(self.schema)
      name = self.uri
      if (index = name.rindex('/')) || index = name.rindex('#')
        name = name[index + 1, name.length - 1]
      end
      if index = name.rindex('.')
        name = name[0..index - 1]
      end
      {name.camelize => json}
    end

    def parse_xml_schema
      Xsd::Document.new(uri, self.schema).schema.json_schemas
    end
  end
end
