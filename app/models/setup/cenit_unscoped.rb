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

    def share_hash(options = {})
      options = options.reverse_merge(self.class.share_options)
      to_hash(options)
    end

    module ClassMethods

      def share_options
        {
          ignore: [:id] + (build_in_data_type.get_protecting || []),
          include_blanks: true
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
