require 'mongoid/cenit_extension'

module Setup
  module CenitUnscoped
    extend ActiveSupport::Concern

    include Mongoid::CenitDocument
    include Mongoid::Timestamps
    include Mongoid::CenitExtension
    include Cenit::Access

    included do
      Setup::Models.regist(self)
    end

    def copy_hash
      share_hash(self.class.copy_options)
    end

    class_methods do

      def inherited(subclass)
        super
        Setup::Models.regist(subclass)
        subclass.build_in_data_type.excluding(build_in_data_type.get_excluding)
        subclass.build_in_data_type.embedding(build_in_data_type.get_embedding)
        subclass.build_in_data_type.and(build_in_data_type.get_to_merge)
      end

      def share_options
        {
          ignore: [:id],
          include_blanks: true,
          protected: true,
          polymorphic: true
        }
      end

      def copy_options
        share_options
      end

      def super_count
        count
      end

      def build_in_data_type
        BuildInDataType.regist(self)
      end

      def mongoid_root_class
        @mongoid_root_class ||=
          begin
            root = self
            root = root.superclass while root.superclass.include?(Mongoid::Document)
            root
          end
      end
    end
  end
end
