module Setup
  module Transformation
    class XsltConversionTransform < Setup::Transformation::AbstractTransform

      class << self

        def run(options = {})
          xml_document = Nokogiri::XSLT(options[:code]).transform(Nokogiri::XML(options[:source].to_xml))
          options[:target] = options[:target_data_type].new_from_xml(xml_document.to_xml)
        end

      end
    end
  end
end
