module Setup
  module Transformation
    class RenitTransform < Setup::Transformation::AbstractTransform
      
      def self.run(options = {})
        type = options[:type]
        style = options[:style]
        source_data_type = options[:source_data_type]
        target_data_type = options[:target_data_type]
        source_exporter = options[:source_exporter]
        target_importer = options[:target_importer]
        transformation = options[:transformation]
        object = options[:object]
        target = options[:target]
        data = options[:data]
        eval(transformation)
      end

      def self.types
        [:Import, :Export, :Update, :Conversion]
      end

    end
  end
end