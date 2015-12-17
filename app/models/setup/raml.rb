module Setup
  class Raml
    include CenitUnscoped

    Setup::Models.exclude_actions_for self, :new, :edit, :translator_update, :convert, :send_to_flow, :delete_all, :import

    BuildInDataType.regist(self).referenced_by(:api_name,:api_version)

    field :api_name, type: String
    field :api_version, type: String
    field :repo, type: String
    field :raml_doc, type: String
    embeds_many :raml_references, class_name: Setup::RamlReference.to_s, inverse_of: :raml
    accepts_nested_attributes_for :raml_references, allow_destroy: true

    validates_presence_of :api_name, :api_version, :raml_doc
    validates_uniqueness_of :api_version, scope: :api_name

    def ref_hash
      hash = {}
      raml_references.each { |p| hash[p.path] = p.content.to_s }
      hash
    end
    def raml_title
      api_name + " | " + api_version
    end

    def build_hash
      ref = self.ref_hash
      Psych.add_domain_type 'include', 'include' do |_, value|
        path = value.gsub(/^(\/)/i, "") || value
        content = ref[path]
        content = Psych.load content if is_yaml?(path)
        content
      end
      Psych.load self.raml_doc
    end

    def extend_path (base_path,raml)
      Psych.add_domain_type 'include', 'include' do |_, value|
        path = value.gsub(/^(\/)/i, "") || value
        base_path + "/" + path
      end
      hash = Psych.load raml
      hash.to_yaml
    end

    def raml_parse
      ::RamlParser::Parser.parse_hash self.build_hash
    end

    def map_collection
      model = raml_parse
      map_connection model
      map_library model
      map_schema model
      map_resource model
    end

    def to_zip
      base_path = api_name + "/" + api_version
      buffer = Zip::OutputStream.write_buffer do |zio|
        zio.put_next_entry("#{base_path}/#{api_name}.raml")
        zio.write self.raml_doc
        ref_hash.each do |path, content|
          zio.put_next_entry base_path + "/" + path
          zio.write content
        end
      end
      { filename: self.raml_title + ".zip", content: buffer.string }
    end

    private

    def is_yaml?(path)
      ['yaml', 'yml', 'raml'].include? path.split('.').last.downcase
    end

    def map_connection(raml)
      hash = {}
      hash["name"] = raml.title + " Connection"
      hash["url"] = raml.base_uri
      hash["headers"] = []
      hash["headers"] << {"key" => "Content-Type", "value" => raml.media_type} if raml.media_type
      if (headers = raml.security_schemes[raml.secured_by.first].described_by.headers)
        headers.each do |k, v|
          value = v.default || "{{#{k.downcase}}}"
          hash["headers"] << {"key" => k, "value" => value}
        end
      end
      Setup::Connection.data_type.create_from_json hash
      hash
    end

    def map_library(raml)
      hash = {}
      hash["name"] = raml.title
      Setup::Library.data_type.create_from_json hash
      hash
    end

    def map_schema(raml)
      hash = {}
      schemas = []
      raml.schemas.each do |key, value|
        schemas << {
          "uri" => key,
          "schema" => value,
          "library" => {
            "_reference" => true,
            "name" => raml.title
          }
        }
      end
      schemas.each { |item| Setup::Schema.data_type.create_from_json item }
      schemas
    end

    def map_resource(raml)

      hash = {}
      hooks = []
      raml.resources.each do |item|
        item.methods.each do |_, v|

          model = if ["POST", "PUT", "PATCH", "DELETE"].include?(v.method)
                    v.bodies[raml.media_type].schema_name if v.bodies[raml.media_type]
                  elsif v.responses[200]
                    v.responses[200].bodies[raml.media_type].schema_name if v.responses[200].bodies[raml.media_type]
                  elsif v.responses[201]
                    v.responses[201].bodies[raml.media_type].schema_name if v.responses[201].bodies[raml.media_type]
                  else
                    nil
                  end

          name = raml.title + " | " + (model || item.display_name) + " " + v.method

          parameters = []
          headers = []
          template_parameters = []

          v.query_parameters.each do |key, value|
            parameters << {"key" => key, "value" => "{{#{key}}}"}
            template_parameters << {"key" => key, "value" => (value.default || value.example)} if (value.default || value.example)
          end

          v.headers.each do |key, value|
            headers << {"key" => key, "value" => "{{#{key}}}"}
            template_parameters << {"key" => key, "value" => (value.default || value.example)} if (value.default || value.example)
          end

          item.uri_parameters.each do |key, value|
            template_parameters << {"key" => key, "value" => (value.default || value.example)} if (value.default || value.example)
          end

          hooks << {"name" => name,
                    "path" => item.relative_uri.gsub("{", "{{").gsub("}", "}}"),
                    "method" => v.method,
                    "parameters" => parameters,
                    "headers" => headers,
                    "template_parameters" => template_parameters
          }

        end
      end
      hooks.each { |item| Setup::Webhook.data_type.create_from_json item }
      hooks
    end

  end
end