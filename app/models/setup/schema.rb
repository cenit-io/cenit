require 'xsd/include_missing_exception'

module Setup
  class Schema < Validator
    include CenitScoped
    include DataTypeValidator
    include CustomTitle

    BuildInDataType.regist(self).with(:uri, :schema).embedding(:data_types).including(:library).referenced_by(:library, :uri)

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

    def title
      uri
    end

    def scope_title
      library && library.name
    end

    def validates_configuration
      self.name = "#{library.name} | #{uri}" unless name.present?
      super
    end

    def load_models(options = {})
      unless @data_types_to_reload
        reload
        @data_types_to_reload = data_types.activated
      end
      if @data_types_to_reload.present?
        models = Set.new
        @data_types_to_reload.each do |data_type|
          data_type.reload
          models += data_type.load_models(options)[:loaded] if data_type.activated
        end
        RailsAdmin::AbstractModel.update_model_config(models)
      end
    end

    def include_missing?
      @include_missing
    end

    attr_reader :include_missing_message

    def run_after_initialized
      if @errors_cache.nil?
        @errors_cache = Hash.new { |h, k| h[k] = [] }
        @include_missing = false
        @data_types_to_keep = Set.new
        @new_data_types = []
        if self.new_record? && self.library && self.library.schemas.where(uri: self.uri).first
          @errors_cache[:uri] << errors.add(:uri, "is is already taken on library #{self.library.name}")
        else
          begin
            schemas = json_schemas
            updated_data_types = []
            new_data_type_names = []
            data_types.each do |data_type|
              if schemas.has_key?(data_type.name)
                data_type.model_schema = schemas[data_type.name].to_json
                schemas[data_type.name] = data_type
                if data_type.new_record?
                  @new_data_types << data_type
                  new_data_type_names << data_type.name
                else
                  updated_data_types << data_type
                end
              end
            end
            new_data_type_names += schemas.keys.select { |name| schemas[name].is_a?(Hash) }
            if library && (conflicts = Setup::Model.all.any_in(name: new_data_type_names).and(library_id: library.id)).present?
              conflicts.each { |existing_data_type| @errors_cache[:schema] << errors.add(:schema, "model name #{existing_data_type.name} is already taken on library #{library.name}") }
            else
              schemas.each do |name, schema|
                if (data_type = schema).is_a?(Hash)
                  @new_data_types << (data_type = Setup::DataType.new(name: name, model_schema: schema.to_json, library: library))
                  self.data_types << data_type
                end
                if data_type && data_type.validate_model
                  @data_types_to_keep << data_type
                else
                  data_type.errors.each do |attribute, error|
                    @errors_cache[:schema] << errors.add(:schema, "when defining model #{name} on attribute '#{attribute}': #{error}")
                  end if data_type
                  destroy_data_types
                  return false
                end
              end
            end
            if new_record?
              @data_types_to_reload = []
            else
              report = Model.shutdown(data_types.activated, report_only: true)
              @data_types_to_reload = report[:destroyed].collect(&:data_type).uniq.select(&:activated)
              Model.shutdown(data_types.activated)
              data_types.each do |data_type|
                unless @data_types_to_keep.include?(data_type)
                  data_type.destroy
                  @data_types_to_reload.delete(data_type)
                end
              end
              updated_data_types.each { |data_type| data_type.save unless @data_types_to_reload.include?(data_type) }
            end
          rescue Exception => ex
            #TODO Delete raise
            #raise ex
            if @include_missing = ex.is_a?(Xsd::IncludeMissingException)
              @include_missing_message = ex.message
            end
            @errors_cache[:schema] << errors.add(:schema, ex.message)
            destroy_data_types
          end
        end
      else
        @errors_cache.each { |key, message| errors.add(key, message) }
      end
      errors.blank?
    end

    def cenit_ref_schema(options = {})
      options = {service_url: Cenit.service_url, service_schema_path: Cenit.service_schema_path}.merge(options)
      send("cenit_ref_#{schema_type}", options)
    end

    def data_type
      data_types.last
    end

    def validate_file_record(file)
      case schema_type
      when :json_schema
        begin
          JSON::Validator.validate!(@schema ||= data_types.first.merged_schema(recursive: true), JSON.parse(file.data))
          []
        rescue Exception => ex
          [ex.message]
        end
      when :xml_schema
        Nokogiri::XML::Schema(cenit_ref_schema).validate(Nokogiri::XML(file.data))
      end
    end

    def auto_save_references_for?(relation)
      relation.to_s == :data_types.to_s
    end

    def parse_schema
      @parsed_schema ||=
        begin
          self.schema = schema.strip
          if schema.start_with?('{') || self.schema.start_with?('[')
            self.schema_type = :json_schema
            parse_json_schema
          else
            self.schema_type = :xml_schema
            parse_xml_schema
          end
        end
    end

    def json_schemas
      bind_includes
      parse_schema.is_a?(Hash) ? @parsed_schema : @parsed_schema.json_schemas
    end

    def bind_includes
      unless @includes_binded
        @parsed_schema.bind_includes(library) unless parse_schema.is_a?(Hash)
        @includes_binded = true
      end
    end

    def included?(qualified_name, visited = Set.new)
      return false if visited.include?(self) || visited.include?(@parsed_schema)
      visited << self
      data_types.any? { |data_type| data_type.name == qualified_name } ||
        if parse_schema.is_a?(Hash)
          @parsed_schema.has_key?(qualified_name)
        else
          @parsed_schema.included?(qualified_name, visited)
        end
    end

    def save_data_types
      if run_after_initialized
        self_optimizer = false
        unless optimizer = Setup::DataTypeOptimizer.optimizer
          optimizer = Setup::DataTypeOptimizer.new
          self_optimizer = true
        end
        optimizer.regist_data_types(@data_types_to_keep.blank? ? data_types : @data_types_to_keep)
        if self_optimizer
          optimizer.save_data_types.each { |error| errors.add(:base, error) }
        end
      end
      errors.blank?
    end

    private

    def destroy_data_types
      @shutdown_report = Model.shutdown(@new_data_types || data_types.activated, destroy: true)
    end

    def parse_json_schema
      {uri => JSON.parse(self.schema)}
    end

    def parse_xml_schema
      Xsd::Document.new(uri, self.schema).schema
    end

    def cenit_ref_json_schema(options = {})
      schema
    end

    def cenit_ref_xml_schema(options = {})
      doc = Nokogiri::XML(schema)
      cursor = doc.root.first_element_child
      while cursor
        if %w(import include redefine).include?(cursor.name) && (attr = cursor.attributes['schemaLocation'])
          attr.value = options[:service_url].to_s + options[:service_schema_path] + '?' +
            {
              key: Account.current.owner.unique_key,
              library_id: library.id.to_s,
              uri: Cenit::Utility.abs_uri(uri, attr.value)
            }.to_param
        end
        cursor = cursor.next_element
      end
      doc.to_xml
    end
  end
end
