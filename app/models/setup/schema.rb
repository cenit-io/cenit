module Setup
  class Schema
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include Trackable

    belongs_to :library, class_name: Setup::Library.to_s, inverse_of: :schemas

    field :uri, type: String
    field :schema, type: String

    has_many :data_types, class_name: Setup::DataType.to_s, dependent: :destroy

    validates_presence_of :library, :uri, :schema

    before_save :create_data_types
    after_save :bind_data_types
    before_destroy :destroy_data_types

    def load_models(options={})
      models = Set.new
      data_types.each do |data_type|
        if data_type.activated
          models += data_type.load_models(options)[:loaded]
        end
      end
      RailsAdmin::AbstractModel.update_model_config(models)
    end

    private

    def create_data_types
      @data_types_to_save = Set.new
      @data_types_to_destroy = []
      @data_types_to_reload = []
      if self.new_record? && self.library.schemas.where(uri: self.uri).first
        errors.add(:uri, "is is already taken on library #{self.library.name}")
        return false
      end
      begin
        return false unless errors.blank?
        parse_schemas.each do |name, schema|
          if data_type = self.data_types.where(name: name).first
            @data_types_to_reload << data_type if data_type.loaded?
            data_type.schema = schema.to_json
          elsif self.library.find_data_type_by_name(name)
            errors.add(:schema, "model name #{name} is already taken on library")
          else
            data_type = Setup::DataType.create(name: name, schema: schema.to_json)
            @data_types_to_destroy << data_type
          end
          if data_type && data_type.errors.blank? && data_type.valid?
            @data_types_to_save << data_type
          else
            data_type.errors.each do |attribute, error|
              errors.add(:schema, "when defining model #{name} on attribute '#{attribute}': #{error}")
            end if data_type
            destroy_data_types
            return false
          end
        end
        self.data_types.delete_if { |data_type| !@data_types_to_save.include?(data_type) }
      rescue Exception => ex
        raise ex
        puts "ERROR: #{errors.add(:schema, ex.message).to_s}"
        destroy_data_types
        return false
      end
      return true
    end

    def bind_data_types
      @data_types_to_save.each do |data_type|
        data_type.uri = self
        data_type.save
      end
      unless @data_types_to_reload.empty?
        DataType.shutdown(@data_types_to_reload)
        @data_types_to_reload.each { |data_type| data_type.load_model(reload: true)}
      end
    end

    def destroy_data_types
      DataType.shutdown(@data_types_to_destroy || self.data_types, destroy: true)
    end

    def parse_schemas
      self.schema = self.schema.strip
      if self.schema.start_with?('{')
        parse_json_schema
      else
        parse_xml_schema
      end
    end

    def parse_json_schema
      json = JSON.parse(self.schema)
      if json['type'] || json['allOf']
        name = self.uri
        if (index = name.rindex('/')) || index = name.rindex('#')
          name = name[index+1, name.length-1]
        end
        if index = name.rindex('.')
          name = name[0..index-1]
        end
        {name.camelize => json}
      else
        json
      end
    end

    def parse_xml_schema
      Xsd::Document.new(uri, self.schema).schema.json_schemas
    end
  end
end