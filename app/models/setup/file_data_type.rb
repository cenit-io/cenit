require 'stringio'

module Setup
  class FileDataType < Model

    SCHEMA =
      {
        type: :object,
        properties:
          {
            filename: {
              title: 'File name',
              type: :string
            },
            contentType: {
              title: 'Content type',
              type: :string
            },
            length: {
              title: 'Size',
              type: :integer
            },
            uploadDate: {
              title: 'Uploaded at',
              type: :string,
              format: :time
            },
            file: {
              type: :object,
              properties: {
                chunks: {
                  type: :array,
                  items: {
                    type: :object,
                    properties: {},
                  },
                  referenced: true,
                  visible: false
                }
              },
              referenced: true,
              visible: false,
              virtual: true
            }
          }
      }.to_json.freeze

    BuildInDataType.regist(self).referenced_by(:name, :library).with(:title, :name, :_type, :validator)

    belongs_to :library, class_name: Setup::Library.to_s, inverse_of: :file_data_types
    belongs_to :validator, class_name: Setup::Validator.to_s, inverse_of: nil

    attr_readonly :library

    validates_presence_of :library

    before_save do
      self.title = self.name if title.blank?
    end

    def data_type_collection_name
      Account.tenant_collection_name(data_type_name)
    end

    def all_data_type_collections_names
      [name = data_type_collection_name, name + '.files', name + '.chunks']
    end

    def is_object?
      true
    end

    def model_schema
      SCHEMA
    end

    def validate_file!(readable)
      readable.rewind
      validator.validate_data!(readable.read) if validator.present?
      readable.rewind
    end

    def create_from(string_or_readable, attributes={})
      raise Exception("Model '#{on_library_title}' is not loaded") unless model = self.model
      temporary_file = nil
      readable =
        if string_or_readable.is_a?(String)
          temporary_file = Tempfile.new('tmp')
          temporary_file.write(string_or_readable)
          temporary_file.rewind
          attributes = default_attributes.merge(attributes)
          Cenit::Utility::Proxy.new(temporary_file, original_filename: attributes[:filename])
        else
          string_or_readable
        end
      validate_file!(readable)
      attributes = attributes.merge(filename: readable.original_filename) unless attributes[:filename]
      file = model.file_model.namespace.put(readable, attributes)
      temporary_file.close! if temporary_file
      model.where(file: file).first
    end

    def create_from_json(json_or_readable, attributes={})
      data = json_or_readable
      unless validator.nil? || validator.schema_type == :json_schema
        data = ((data.is_a?(String) || data.is_a?(Hash)) && data) || data.read
        data = validator.schema.data_types.first.new_from_json(data).to_xml
      end
      create_from(data, attributes)
    end

    def create_from_xml(string_or_readable, attributes={})
      data = string_or_readable
      unless validator.nil? || validator.schema_type == :xml_schema
        data = (data.is_a?(String) && data) || data.read
        data = validator.schema.data_types.first.new_from_xml(data).to_json
      end
      create_from(data, attributes)
    end

    protected

    def default_attributes
      if validator
        {
          filename: "file_#{DateTime.now.strftime('%Y-%m-%d_%Hh%Mm%S')}" +
            case validator.schema_type
            when :json_schema
              '.json'
            when :xml_schema
              '.xml'
            end,
          contentType:
            case validator.schema_type
            when :json_schema
              'application/json'
            when :xml_schema
              'application/xml'
            end
        }
      else
        {}
      end
    end

    def do_load_model(report)
      Object.const_set(data_type_name, model = Class.new { class_eval(&FILE_MODEL_MIXIN); self })
      file_model = Cenit::GridFs.build_grid_file_model(model)
      model.belongs_to(:file, class_name: file_model.to_s, inverse_of: nil)
      [file_model, file_model.chunk_model].each { |m| m.include(Setup::ClassAffectRelation) }
      file_model.affects_to(model)
      {
        model => ['', title],
        file_model => %w(/properties/file File),
        file_model.chunk_model => %w(/properties/file/properties/chunks/items Chunk)
      }.each do |model, values|
        model.class_eval("def self.data_type
            Setup::FileDataType.where(id: '#{self.id}').first
          end
          def self.schema_path
            '#{values[0]}'
          end
          def self.title
            '#{values[1]}'
          end
          def orm_model
            self.class
          end")
      end
      model.class_eval do
        class << self

          def file_model
            const_get(:File.to_s)
          end

          def chunk_model
            file_model.chunk_model
          end

          def all_collections_names
            [collection_name, file_model.collection_name, chunk_model.collection_name]
          end
        end
      end
      model
    end

    private

    FILE_MODEL_MIXIN = proc do
      Setup::Model.to_include_in_models.each do |module_to_include|
        include(module_to_include) unless include?(module_to_include) || [RailsAdminDynamicCharts::Datetime].include?(module_to_include)
      end

      field :filename, type: String
      field :contentType, type: String
      field :length, type: Integer
      field :uploadDate, type: Time

      def update_from(grid_file)
        self.file = grid_file
        %w(filename contentType length uploadDate).each { |method| send("#{method}=", grid_file.send(method)) }
        save
      end

      before_destroy do
        file.destroy
      end

      def to_json(options = {})
        data = file.data
        data_type = self.class.data_type
        unless (validator = data_type.validator).nil? || validator.schema_type == :json_schema
          ignore = (options[:ignore] || [])
          ignore = [ignore] unless ignore.is_a?(Enumerable)
          ignore = ignore.select { |p| p.is_a?(Symbol) || p.is_a?(String) }.collect(&:to_sym)
          options[:ignore] = ignore
          data = validator.schema.data_types.first.new_from_xml(data).to_json(options)
        end
        hash = JSON.parse(data)
        hash = {data_type.name.downcase => hash} if options[:include_root]
        if options[:pretty]
          JSON.pretty_generate(hash)
        else
          options[:include_root] ? hash.to_json : data
        end
      end

      def to_xml(options = {})
        data = file.data
        data_type = self.class.data_type
        unless (validator = data_type.validator).nil? || validator.schema_type == :xml_schema
          data = validator.schema.data_types.first.new_from_json(data).to_xml(options)
        end
        Nokogiri::XML::Document.parse(data)
        data
      end

      class << self
        def update_for(grid_file)
          wrapper = where(file: grid_file).first || new
          wrapper.update_from(grid_file)
        end
      end
    end
  end
end