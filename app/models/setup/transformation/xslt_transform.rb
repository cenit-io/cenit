module Setup
  module Transformation
    class XsltTransform < Setup::Transformation::AbstractTransform
      
      def self.run(transformation, document, options = {})
        Hash.from_xml(Nokogiri::XSLT(transformation).transform(to_xml_document(document)).to_s)
      end

    end
  end
end