module Setup
  module MongoffWrapper
    extend ActiveSupport::Concern

    module ClassMethods

      def data_type_id
        @data_type_id ||= Setup::SchemaDataType.all.first.id
      end

      def data_type
        Setup::SchemaDataType.where(id: data_type_id).first
      end
    end
  end
end