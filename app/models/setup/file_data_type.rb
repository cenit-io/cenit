require 'stringio'

module Setup
  class FileDataType < DataType

    BuildInDataType.regist(self).referenced_by(:name, :library).with(:title, :name, :slug, :_type, :validators, :schema_data_type).including(:library)

    has_and_belongs_to_many :validators, class_name: Setup::Validator.to_s, inverse_of: nil
    belongs_to :schema_data_type, class_name: Setup::SchemaDataType.to_s, inverse_of: nil

    attr_readonly :library

    before_save :validate_configuration

    def validate_configuration
      self.title = self.name if title.blank?
      validators_classes = Hash.new { |h, k| h[k] = [] }
      if validators.present?
        validators.each { |validator| validators_classes[validator.class] << validator }
        validators_classes.delete(Setup::AlgorithmValidator)
        if validators_classes.size == 1 && validators_classes.values.first.size == 1
          self.schema_data_type = validators_classes.values.first.first.schema_data_type
        else
          if schema_data_type.present?
            errors.add(:schema_data_type, 'is not allowed if no format validator is defined')
            self.schema_data_type = nil
          end
          if validators_classes.count > 1
            errors.add(:validators, "include validators of exclusive types: #{validators_classes.keys.to_a.collect(&:to_s).to_sentence}")
          end
          validators_classes.each do |validator_class, validators|
            errors.add(:validators, "include multiple validators of the same exclusive type #{validator_class}: #{validators.collect(&:name).to_sentence}") if validators.count > 1
          end
        end
      else
        errors.add(:schema_data_type, 'is not allowed if no format validator is defined') if schema_data_type.present?
        self.schema_data_type = nil
      end
      errors.blank?
    end

    def ready_to_save?
      @validators_selected
    end

    def format_validator
      @format_validator ||= validators.detect { |validator| validator.is_a?(Setup::FormatValidator) }
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

    def schema
      Mongoff::GridFs::FileModel::SCHEMA
    end

    def validate_file(file)
      errors = []
      validators.each do |v|
        next if errors.present?
        errors += v.validate_file_record(file)
      end
      errors
    end

    def validate_file!(file)
      if (errors = validate_file(file)).present?
        raise Exception.new('Invalid file data: ' + errors.to_sentence)
      end
    end

    def new_from(string_or_readable, options = {})
      options.reverse_merge!(default_attributes)
      file = records_model.new
      file.data = string_or_readable
      file
    end

    def create_from(string_or_readable, options = {})
      if data_type_methods.any? { |alg| alg.name == 'create_from' }
        return method_missing(:create_from, string_or_readable, options)
      end
      options = default_attributes.merge(options)
      file = new_from(string_or_readable, options)
      file.save(options)
      file
    end

    def new_from_json(json_or_readable, options = {})
      if data_type_methods.any? { |alg| alg.name == 'new_from_json' }
        return method_missing(:new_from_json, json_or_readable, options)
      end
      data = json_or_readable
      unless format_validator.nil? || format_validator.data_format == :json
        data = ((data.is_a?(String) || data.is_a?(Hash)) && data) || data.read
        data = format_validator.format_from_json(data, schema_data_type: schema_data_type)
        options[:valid_data] = true
      end
      new_from(data, options)
    end

    def new_from_xml(string_or_readable, options = {})
      if data_type_methods.any? { |alg| alg.name == 'new_from_xml' }
        return method_missing(:new_from_xml, string_or_readable, options)
      end
      data = string_or_readable
      unless format_validator.nil? || format_validator.data_format == :xml
        data = (data.is_a?(String) && data) || data.read
        data = format_validator.format_from_xml(data, schema_data_type: schema_data_type)
        options[:valid_data] = true
      end
      new_from(data, options)
    end

    def new_from_edi(string_or_readable, options = {})
      if data_type_methods.any? { |alg| alg.name == 'new_from_edi' }
        return method_missing(:new_from_edi, string_or_readable, options)
      end
      data = string_or_readable
      unless format_validator.nil? || format_validator.data_format == :edi
        data = (data.is_a?(String) && data) || data.read
        data = format_validator.format_from_edi(data, schema_data_type: schema_data_type)
        options[:valid_data] = true
      end
      new_from(data, options)
    end

    def default_attributes
      {
        default_filename: "file_#{DateTime.now.strftime('%Y-%m-%d_%Hh%Mm%S')}" + ((extension = format_validator.try(:file_extension)) ? ".#{extension}" : ''),
        default_contentType: format_validator.try(:content_type) || 'application/octet-stream'
      }
    end

    protected

    def do_load_model(report)
      Object.const_set(data_type_name, model = Class.new)
      model.instance_variable_set(:@grid_fs_file_model, grid_fs_file_model = Mongoff::GridFs::FileModel.new(self, observable: false))
      model.include(FileModel)
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

    module FileModel
      extend ActiveSupport::Concern

      Setup::DataType.to_include_in_models.each do |module_to_include|
        include(module_to_include) unless include?(module_to_include) ||
          [
            Mongoid::Timestamps #, RailsAdminDynamicCharts::Datetime
          ].include?(module_to_include)
      end

      include Mongoff::GridFs::FileFormatter

      included do
        field :created_at, type: Time
        field :updated_at, type: Time
        field :filename, type: String
        field :contentType, type: String, default: -> { Mongoff::GridFs::FileModel::SCHEMA['properties']['contentType']['default'] }
        field :length, type: Integer
        field :uploadDate, type: Time
        field :chunkSize, type: String
        field :md5, type: String
        field :aliases
        field :metadata

        before_destroy do
          file.destroy
        end
      end

      def write_attribute(name, value)
        @custom_contentType = true if name.to_s == :contentType.to_s
        super
      end

      def name
        filename
      end

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
        [:filename, :aliases, :metadata].each { |field| file[field] = self[field] }
        file[:contentType] = self[:contentType] if @custom_contentType
        if @new_data
          file.data = @new_data
          unless file.save(options)
            @errors = file.errors
            return false
          end
        end
        self.updated_at = Time.now
        self.created_at = updated_at unless created_at.present?
        updated = !update_document(options)
        if new_record?
          if updated
            @new_record = false
          else
            file.destroy if @errors.present?
          end
        end
        updated
      end

      def method_missing(symbol, *args)
        file.method_missing(symbol, *args)
      end

      module ClassMethods

        def all_storage_collections_names
          instance_variable_get(:@grid_fs_file_model).all_storage_collections_names
        end
      end
    end
  end
end