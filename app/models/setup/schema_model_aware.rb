module Setup
  module SchemaModelAware
    extend ActiveSupport::Concern

    module ClassMethods

      def schema_path
        ''
      end

      def schema
        data_type = self.data_type
        schema = data_type.merged_schema
        schema_path.split('/').each { |token| schema = data_type.merge_schema(schema[token]) if token.present? }
        schema
      end

    end

  end
end
