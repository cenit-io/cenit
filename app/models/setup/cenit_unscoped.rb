require 'mongoid/cenit_extension'

module Setup
  module CenitUnscoped
    extend ActiveSupport::Concern

    include Mongoid::CenitDocument
    include Mongoid::Timestamps
    include Mongoid::CenitExtension

    included do
      Setup::Models.regist(self)
    end

    module ClassMethods

      def inherited(subclass)
        super
        Setup::Models.regist(subclass)
        subclass.deny Setup::Models.excluded_actions_for(self)
        subclass.build_in_data_type.excluding(build_in_data_type.get_excluding)
      end

      def share_options
        {
          ignore: [:id],
          include_blanks: true,
          protected: true,
          polymorphic: true
        }
      end

      def super_count
        count
      end

      def build_in_data_type
        BuildInDataType.regist(self)
      end

      def allow(*actions)
        Setup::Models.included_actions_for self, *actions
      end

      def deny(*actions)
        Setup::Models.excluded_actions_for self, *actions
      end
    end
  end
end
