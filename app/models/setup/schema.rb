require 'xsd/include_missing_exception'

module Setup
  class Schema < Validator
    include SharedEditable
    include NamespaceNamed
    include Setup::FormatValidator
    include CustomTitle

    build_in_data_type.with(:namespace, :uri, :schema).referenced_by(:namespace, :uri)

    shared_deny :simple_generate, :bulk_generate

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

    def validates_before
      super
      self.name = uri unless name.present?
      self.schema = schema.strip
      self.schema_type =
        if schema.start_with?('{') || self.schema.start_with?('[')
          :json_schema
        else
          :xml_schema
        end
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
      else
        ns = namespace
        if ref.is_a?(Hash)
          ns = ref['namespace']
          ref = ref['name']
        end
        (sch = Setup::Schema.where(namespace: ns, uri: ref).first) &&
          sch.schema
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

    def cenit_ref_schema(options = {})
      options = {
        service_url: Cenit.routed_service_url,
        schema_service_path: Cenit.schema_service_path
      }.merge(options)
      send("cenit_ref_#{schema_type}", options)
    end

    private

    def cenit_ref_json_schema(options = {})
      schema
    end

    def cenit_ref_xml_schema(options = {})
      doc = Nokogiri::XML(schema)
      cursor = doc.root.first_element_child
      while cursor
        if %w(import include redefine).include?(cursor.name) && (attr = cursor.attributes['schemaLocation'])
          token = Cenit::TenantToken.create data: { ns: namespace, uri: abs_uri(uri, attr.value) },
                                            token_span: 1.hour
          attr.value = "#{options[:service_url]}#{"/#{options[:schema_service_path]}".squeeze('/')}?token=#{token.token}"
        end
        cursor = cursor.next_element
      end
      doc.to_xml
    end

    def parse_json_schema
      { uri => JSON.parse(self.schema) }
    end

    def parse_xml_schema
      Xsd::Document.new(uri, self.schema).schema
    end

    def abs_uri(base_uri, uri)
      uri = URI.parse(uri.to_s)
      return uri.to_s unless uri.relative?

      base_uri = URI.parse(base_uri.to_s)
      uri = uri.to_s.split('/')
      path = base_uri.path.split('/')
      begin
        path.pop
      end while uri[0] == '..' ? uri.shift && true : false

      path = (path + uri).join('/')

      uri = URI.parse(path)
      uri.scheme = base_uri.scheme
      uri.host = base_uri.host
      uri.to_s
    end
  end
end
