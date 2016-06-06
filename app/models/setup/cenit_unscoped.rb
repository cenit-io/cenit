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

      def deny(*args)
        Setup::Models.exclude_actions_for self, *args
      end
    end
  end
end
