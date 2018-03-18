module Setup
  class XsltTemplate < Template
    include SnippetCodeTemplate
    include RailsAdmin::Models::Setup::XsltTemplateAdmin

    def validates_configuration
      method = output_method
      if %w(xml html text).include?(method)
        if mime_type.present?
          unless mime_type[method]
            errors.add(:mime_type, "is not compatible with transformation method '#{method}'")
          end
        else
          self.mime_type =
            case method
            when 'xml'
              'application/xml'
            when 'html'
              'text/html'
            when 'text'
              'text/plain'
            else
              nil
            end
        end
      else
        errors.add(:code, "defines a non supported output method: #{method}")
      end
      super
    end

    def mime_type_enum
      %w(application/xml text/html text/plain)
    end

    def execute(options)
      code = options[:code] || self.code
      xsl_doc = Nokogiri::XSLT(code)
      xml_document = xsl_doc.transform(Nokogiri::XML(options[:source].to_xml))
      if output_method(code) == 'text'
        xml_document.content
      else
        xml_document.to_xml
      end
    end

    def output_method(xml_doc = code)
      xml_doc ||= code
      xml_doc = Nokogiri::XML(xml_doc) unless xml_doc.is_a?(Nokogiri::XML::Document)
      xsl_prefix = xml_doc.root.namespace.prefix
      if (e = xml_doc.xpath("//#{xsl_prefix}:output").first) && (e = e.attribute('method'))
        e.value
      else
        'xml' #TODO Infers html method from structure
      end
    end

    def ready_to_save?
      true
    end

    def can_be_restarted?
      false
    end
  end
end
