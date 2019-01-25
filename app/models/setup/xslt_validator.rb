module Setup
  class XsltValidator < CustomValidator
    include SnippetCode
    include ::RailsAdmin::Models::Setup::XsltValidatorAdmin

    legacy_code_attribute :xslt

    build_in_data_type.referenced_by(:namespace, :name)

    field :schema_type, type: Symbol

    def code_extension
      '.xsl'
    end

    def validate_data(data)
      unless data.is_a?(Nokogiri::XML::Document)
        unless data.is_a?(String)
          data =
            if data.respond_to?(:to_xml)
              data.to_xml
            else
              data
            end.to_s
        end
        data = Nokogiri::XML(data)
      end
      Nokogiri::XSLT(code).transform(data)
      []
    rescue Exception => ex
      [ex.message]
    end

  end
end
