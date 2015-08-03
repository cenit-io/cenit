require 'stringio'

module Setup
  class FileDataType < Model

    BuildInDataType.regist(self).referenced_by(:name, :library).with(:title, :name, :_type, :validator)

    belongs_to :library, class_name: Setup::Library.to_s, inverse_of: :file_data_types
    belongs_to :validator, class_name: Setup::Validator.to_s, inverse_of: nil

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

    def validate_file(readable)
      readable.rewind
      errors = validator.present? ? validator.validate_data(readable.read) : []
      readable.rewind
      errors
    end

    def validate_file!(readable)
      if (errors = validate_file(readable)).present?
        raise Exception.new('Invalid file data: ' + errors.to_sentence)
      end
    end

    def create_from(string_or_readable, options = {})
      options = default_attributes.merge(options)
      file = records_model.new
      file.data = string_or_readable
      file.save(options)
      file
    end

    def create_from_json(json_or_readable, options = {})
      data = json_or_readable
      unless validator.nil? || validator.data_format == :json
        data = ((data.is_a?(String) || data.is_a?(Hash)) && data) || data.read
        data = validator.format_from_json(data)
        options[:valid_data] = true
      end
      create_from(data, options)
    end

    def create_from_xml(string_or_readable, options = {})
      data = string_or_readable
      unless validator.nil? || validator.data_format == :xml
        data = (data.is_a?(String) && data) || data.read
        data = validator.format_from_xml(data)
        options[:valid_data] = true
      end
      create_from(data, options)
    end

    def create_from_edi(string_or_readable, options = {})
      data = string_or_readable
      unless validator.nil? || validator.data_format == :edi
        data = (data.is_a?(String) && data) || data.read
        data = validator.format_from_edi(data)
        options[:valid_data] = true
      end
      create_from(data, options)
    end

    def default_attributes
      {
        default_filename: "file_#{DateTime.now.strftime('%Y-%m-%d_%Hh%Mm%S')}" + ((extension = validator.try(:file_extension)) ? ".#{extension}" : ''),
        default_contentType: validator.try(:content_type) || 'application/octet-stream'
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

      Setup::Model.to_include_in_models.each do |module_to_include|
        include(module_to_include) unless include?(module_to_include) || [Mongoid::Timestamps, RailsAdminDynamicCharts::Datetime].include?(module_to_include)
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
        [:filename, :aliases, :metadata].each { |field| file[field] =  self[field] }
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

      module ClassMethods

        def all_storage_collections_names
          instance_variable_get(:@grid_fs_file_model).all_storage_collections_names
        end
      end
    end
  end
end