require 'stringio'

module Setup
  class FileDataType < DataType
    include RailsAdmin::Models::Setup::FileDataTypeAdmin

    validates_presence_of :namespace

    build_in_data_type.referenced_by(:namespace, :name).with(:namespace, :name, :id_type, :title, :slug, :_type, :validators, :schema_data_type, :events, :before_save_callbacks, :records_methods, :data_type_methods)

    allow :new, :import, :pull_import, :bulk_cross, :simple_cross, :bulk_expand, :simple_expand, :download_file, :copy, :switch_navigation, :render_chart

    shared_deny :simple_delete_data_type, :bulk_delete_data_type

    field :id_type, type: String, default: -> { self.class.id_type_enum.values.first }
    field :store_in, :type => Class, :default => :local

    has_and_belongs_to_many :validators, class_name: Setup::Validator.to_s, inverse_of: nil
    belongs_to :schema_data_type, class_name: Setup::JsonDataType.to_s, inverse_of: nil

    validates_inclusion_of :id_type, in: ->(file_data_type) { file_data_type.class.id_type_enum.values + [nil] }

    before_save :validate_configuration

    def validate_configuration
      self.title = self.name if title.blank?
      validators_classes = Hash.new { |h, k| h[k] = [] }
      if validators.present?
        validators.each { |validator| validators_classes[validator.class] << validator }
        validators_classes.delete(Setup::AlgorithmValidator)
        if validators_classes.size == 1 &&
          (validators = validators_classes.values.first).size == 1 &&
          validators[0].is_a?(Setup::EdiValidator)
          self.schema_data_type = validators[0].first.schema_data_type
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
      remove_attribute(:id_type) if default_id_type?
      errors.blank?
    end

    def default_id_type?
      return true if id_type.blank?
      id_options = self.class.id_type_enum.values
      id_type == id_options.first || id_options.exclude?(id_type)
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
      @schema ||=
        begin
          sch = Mongoff::GridFs::FileModel::SCHEMA
          unless default_id_type?
            sch = sch.deep_dup
            sch['properties']['_id'] = { 'type' => id_type }
          end
          sch
        end
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
      if options[:data_type_parser]
        super
      else
        options.reverse_merge!(default_attributes)
        file = records_model.new
        file.data = string_or_readable
        file
      end
    end

    def create_from(string_or_readable, options = {})
      if data_type_methods.any? { |alg| alg.name == 'create_from' }
        return method_missing(:create_from, string_or_readable, options)
      end
      if options[:data_type_parser]
        super
      else
        options = default_attributes.merge(options)
        file = new_from(string_or_readable, options)
        file.save(options)
        file
      end
    end

    def new_from_json(json_or_readable, options = {})
      if data_type_methods.any? { |alg| alg.name == 'new_from_json' }
        return method_missing(:new_from_json, json_or_readable, options)
      end
      if options[:data_type_parser]
        super
      else
        data = json_or_readable
        unless format_validator.nil? || format_validator.data_format == :json
          data = ((data.is_a?(String) || data.is_a?(Hash)) && data) || data.read
          data = format_validator.format_from_json(data, schema_data_type: schema_data_type)
          options[:valid_data] = true
        end
        new_from(data, options)
      end
    end

    def new_from_xml(string_or_readable, options = {})
      if data_type_methods.any? { |alg| alg.name == 'new_from_xml' }
        return method_missing(:new_from_xml, string_or_readable, options)
      end
      if options[:data_type_parser]
        super
      else
        data = string_or_readable
        unless format_validator.nil? || format_validator.data_format == :xml
          data = (data.is_a?(String) && data) || data.read
          data = format_validator.format_from_xml(data, schema_data_type: schema_data_type)
          options[:valid_data] = true
        end
        new_from(data, options)
      end
    end

    def new_from_edi(string_or_readable, options = {})
      if data_type_methods.any? { |alg| alg.name == 'new_from_edi' }
        return method_missing(:new_from_edi, string_or_readable, options)
      end
      if options[:data_type_parser]
        super
      else
        data = string_or_readable
        unless format_validator.nil? || format_validator.data_format == :edi
          data = (data.is_a?(String) && data) || data.read
          data = format_validator.format_from_edi(data, schema_data_type: schema_data_type)
          options[:valid_data] = true
        end
        new_from(data, options)
      end
    end

    def default_attributes
      {
        default_filename: "file_#{DateTime.now.strftime('%Y-%m-%d_%Hh%Mm%S')}" + ((extension = format_validator.try(:file_extension)) ? ".#{extension}" : ''),
        default_contentType: format_validator.try(:content_type) || 'application/octet-stream'
      }
    end

    class << self

      def id_type_enum
        {
          Default: 'default',
          Integer: 'integer',
          String: 'string'
        }
      end

      def store_in_enum
        Cenit.file_stores.map { |fs| [fs.label, fs.name] }.to_h
      end
    end
  end
end
