require 'stringio'

module Setup
  class FileDataType < DataType

    build_in_data_type.referenced_by(:namespace, :name).with(:namespace, :name, :title, :slug, :_type, :validators, :schema_data_type, :events, :before_save_callbacks, :records_methods, :data_type_methods)

    has_and_belongs_to_many :validators, class_name: Setup::Validator.to_s, inverse_of: nil
    belongs_to :schema_data_type, class_name: Setup::JsonDataType.to_s, inverse_of: nil

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
      @schema ||= Mongoff::GridFs::FileModel::SCHEMA.merge('edi' => { 'segment' => name })
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
  end
end