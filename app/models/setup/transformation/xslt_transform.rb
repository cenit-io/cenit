module Setup
  module Transformation
    class XsltTransform < Setup::Transformation::AbstractTransform
      
      def self.run(options = {})
        xml = Nokogiri::XSLT(options[:transformation]).transform(options[:object].to_xml)
        options[:target_data_type].new_from_xml(xml)
      end

      def self.types
        [:Conversion]
      end

    end
  end
end