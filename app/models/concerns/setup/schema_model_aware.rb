module Setup
  module SchemaModelAware
    extend ActiveSupport::Concern

    module ClassMethods
      def schema_path
        ''
      end

      def schema
        build_in_data_type.schema
      end
    end
  end
end
