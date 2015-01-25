module Setup
  module Transform
    class XsltTransform < Setup::Transform::AbstractTransform
      
      def self.run(transformation, document, options = {})
        Hash.from_xml(Nokogiri::XSLT(transformation).transform(to_xml_document(document)).to_s)
      end

    end
  end
end