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

    def share_hash
      to_hash(ignore: [:id, :number, :token], include_blanks: true)
    end

    module ClassMethods
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

      def shared_deny(*actions)
        Setup::Models.shared_excluded_actions_for self, *actions
      end

      def shared_allow(*actions)
        Setup::Models.shared_allowed_actions_for self, *actions
      end
    end
  end
end
