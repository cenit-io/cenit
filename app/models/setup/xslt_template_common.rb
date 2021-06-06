module Setup
  module XsltTemplateCommon
    def output_method(xml_doc = code)
      xml_doc ||= code
      xml_doc = Nokogiri::XML(xml_doc) unless xml_doc.is_a?(Nokogiri::XML::Document)
      xsl_prefix = xml_doc.root.namespace.prefix
      if (e = xml_doc.xpath("//#{xsl_prefix}:output").first) && (e = e.attribute('method'))
        e.value
      else
        'xml' #TODO Infers html method from structure
      end
    rescue
      'text'
    end

    def render(xslt, xml)
      xsl_doc = Nokogiri::XSLT(xslt)
      xml_document = xsl_doc.transform(Nokogiri::XML(xml))
      if output_method(xslt) == 'text'
        xml_document.content
      else
        xml_document.to_xml
      end
    end
  end
end
