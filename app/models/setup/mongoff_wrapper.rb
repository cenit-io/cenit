module Setup
  module MongoffWrapper
    extend ActiveSupport::Concern

    module ClassMethods

      def data_type_id
        @data_type_id ||= Setup::JsonDataType.all.first.id
      end

      def data_type
        Setup::JsonDataType.where(id: data_type_id).first
      end
    end
  end
end