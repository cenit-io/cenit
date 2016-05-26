require 'xsd/include_missing_exception'

module Setup
  class Schema < Validator
    include CenitScoped
    include NamespaceNamed
    include Setup::FormatValidator
    include CustomTitle

    BuildInDataType.regist(self).with(:namespace, :uri, :schema).referenced_by(:namespace, :uri)

    field :uri, type: String
    field :schema, type: String
    field :schema_type, type: Symbol

    belongs_to :schema_data_type, class_name: Setup::JsonDataType.to_s, inverse_of: nil

    attr_readonly :uri

    validates_presence_of :uri, :schema
    validates_uniqueness_of :uri, scope: :namespace

    def title
      uri
    end

    before_validation :prepare_configuration

    def prepare_configuration
      self.name = uri unless name.present?
      self.schema = schema.strip
      self.schema_type =
        if schema.start_with?('{') || self.schema.start_with?('[')
          :json_schema
        else
          :xml_schema
        end
    end

    def cenit_ref_schema(options = {})
      options = { service_url: Cenit.service_url, service_schema_path: Cenit.service_schema_path }.merge(options)
      send("cenit_ref_#{schema_type}", options)
    end

    def data_format
      schema_type.to_s.split('_').first.to_sym
    end


    def validate_data(data)
      case schema_type
      when :json_schema
        begin
          JSON::Validator.fully_validate(JSON.parse(schema),
                                         JSON.parse(data),
                                         version: :mongoff,
                                         schema_reader: JSON::Schema::CenitReader.new(self),
                                         strict: true)
          []
        rescue Exception => ex
          [ex.message]
        end
      when :xml_schema
        begin
          Nokogiri::XML::Schema(cenit_ref_schema).validate(Nokogiri::XML(data))
        rescue Exception => ex
          [ex.message]
        end
      end
    end

    def find_ref_schema(ref)
      if ref == uri
        self
      elsif (sch = Setup::Schema.where(namespace: namespace, uri: ref).first)
        sch.schema
      else
        nil
      end
    end

    def parse_schema
      @parsed_schema ||=
        case schema_type
        when :json_schema
          parse_json_schema
        when :xml_schema
          parse_xml_schema
        else
          #TODO !!!
        end
    end

    def json_schemas
      bind_includes
      if parse_schema.is_a?(Hash)
        @data_type_name = @parsed_schema.keys.first
        @parsed_schema
      else
        json_schms = @parsed_schema.json_schemas
        if (elements_schms = json_schms.keys.select { |name| name.start_with?('element') }).size == 1
          @data_type_name = elements_schms.first
        end
        json_schms
      end
    end

    def bind_includes
      unless @includes_binded
        parse_schema.bind_includes(namespace_ns) unless parse_schema.is_a?(Hash)
        @includes_binded = true
      end
    end

    def included?(qualified_name, visited = Set.new)
      return false if visited.include?(self) || visited.include?(@parsed_schema)
      visited << self
      if parse_schema.is_a?(Hash)
        @parsed_schema.has_key?(qualified_name)
      else
        @parsed_schema.included?(qualified_name, visited)
      end
    end

    private

    def parse_json_schema
      { uri => JSON.parse(self.schema) }
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
              ns: namespace,
              uri: Cenit::Utility.abs_uri(uri, attr.value)
            }.to_param
        end
        cursor = cursor.next_element
      end
      doc.to_xml
    end
  end
end
