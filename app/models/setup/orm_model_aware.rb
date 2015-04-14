module Setup
  module OrmModelAware
    extend ActiveSupport::Concern

    def orm_model
      self.class
    end

    module ClassMethods
      def data_type
        BuildInDataType.build_ins[self.to_s]
      end
    end
  end
end
