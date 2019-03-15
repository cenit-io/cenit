module Setup
  module OrmModelAware
    extend ActiveSupport::Concern

    def orm_model
      self.class
    end

    module ClassMethods
      def data_type
        if (build_in = BuildInDataType.build_ins[self.to_s])
          build_in.request_db_data_type
        end
      end
    end

  end
end
