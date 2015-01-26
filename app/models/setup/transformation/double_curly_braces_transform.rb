module Setup
  module Transformation
    class DoubleCurlyBracesTransform < Setup::Transformation::AbstractTransform
      
      def self.run(transformation, document, options = {})
        hash_document = to_hash(document) || nil
        template_hash = try JSON.parse(transformation)
        template_hash.each do |key, value|
          if value.is_a?(String) && value =~ /\A\{\{[a-z]+(_|([0-9]|[a-z])+)*(.[a-z]+(_|([0-9]|[a-z])+)*)*\}\}\Z/
            new_value = data_hash
            value[2, value.length - 4].split('.').each do |k|
              next if new_value.nil? || !(template_hash = template_hash.is_a?(Hash) ? template_hash : nil) || new_value = new_value[k]
            end
            template_hash[key] = new_value
          elsif value.is_a?(Hash)
            template_hash[key] = json_transform(value, data_hash)
          end
        end
        template_hash
      end

    end
  end
end