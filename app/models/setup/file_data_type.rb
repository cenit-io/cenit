require 'stringio'

module Setup
  class FileDataType < Model

    BuildInDataType.regist(self).referenced_by(:name, :library).with(:title, :name, :_type, :validator)

    belongs_to :library, class_name: Setup::Library.to_s, inverse_of: :file_data_types
    belongs_to :validator, class_name: Setup::FormatValidator.to_s, inverse_of: nil

    attr_readonly :library

    validates_presence_of :library

    before_save do
      self.title = self.name if title.blank?
    end

    def data_type_storage_collection_name
      "#{super}.files"
    end

    def chunks_storage_collection_name
      data_type_storage_collection_name.gsub(/files\Z/, 'chunks')
    end

    def all_data_type_storage_collections_names
      [data_type_storage_collection_name, chunks_storage_collection_name]
    end

    def mongoff_model_class
      Mongoff::GridFs::FileModel
    end

    def model_schema
      Mongoff::GridFs::FileModel::SCHEMA.to_json
    end

    def validate_file!(readable)
      readable.rewind
      validator.validate_data!(readable.read) if validator.present?
      readable.rewind
    end

    def create_from(string_or_readable, attributes={})
      file = model.new
      file.filename = attributes[:filename]
      file.contentType = attributes[:contentType] if attributes[:contentType]
      file.data = string_or_readable
      file.save
      file
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
      Object.const_set(data_type_name, model = Class.new)
      model.instance_variable_set(:@grid_fs_file_model, grid_fs_file_model = Mongoff::GridFs::FileModel.new(self, observable: false))
      model.class_eval(&FILE_MODEL_MIXIN)
      model.store_in(collection: -> { grid_fs_file_model.collection_name })
      model.class_eval("def self.data_type
            Setup::FileDataType.where(id: '#{self.id}').first
          end
          def self.schema_path
            ''
          end
          def self.title
            '#{title}'
          end
          def orm_model
            self.class
          end")
      model
    end

    private

    FILE_MODEL_MIXIN = proc do
      Setup::Model.to_include_in_models.each do |module_to_include|
        include(module_to_include) unless include?(module_to_include) || [RailsAdminDynamicCharts::Datetime].include?(module_to_include)
      end

      field :filename, type: String
      field :contentType, type: String, default: -> { Mongoff::GridFs::FileModel::SCHEMA['properties']['contentType']['default'] }
      field :length, type: Integer
      field :uploadDate, type: Time
      field :chunkSize, type: String
      field :md5, type: String
      field :aliases
      field :metadata

      def grid_fs_file_model
        self.class.instance_variable_get(:@grid_fs_file_model)
      end

      def file
        @file ||=
          if new_record?
            f = grid_fs_file_model.new
            f.id = id
            f
          else
            grid_fs_file_model.where(id: id).first
          end
      end

      def data=(string_or_readable)
        @new_data = string_or_readable
      end

      def data
        file.data
      end

      def save(options = {})
        if @new_data
          file.data = @new_data
          if file.save
            @new_record = false
          else
            @errors = file.errors
            return false
          end
        end
        file.destroy unless super
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
        def all_storage_collections_names
          instance_variable_get(:@grid_fs_file_model).all_storage_collections_names
        end
      end
    end
  end
end