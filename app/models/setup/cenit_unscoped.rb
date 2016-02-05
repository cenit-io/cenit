require 'mongoid/cenit_extension'

module Setup
  module CenitUnscoped
    extend ActiveSupport::Concern

    include Mongoid::CenitDocument
    include Mongoid::Timestamps
    include Mongoid::CenitExtension
    # include Trackable

    included do
      Setup::Models.regist(self)

      index created_at: -1

      default_scope -> { desc(:created_at) }
    end

    def share_hash
      to_hash(ignore: [:id, :number, :token], include_blanks: true)
    end
  end
end
