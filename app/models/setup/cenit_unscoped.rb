module Setup
  module CenitUnscoped
    extend ActiveSupport::Concern

    include Mongoid::Document
    include Mongoid::Timestamps
    include Mongoid::CenitExtension
    # include Trackable

    included do
      Setup::Models.regist(self)
    end

    def share_hash
      to_hash(ignore: [:id, :number, :token])
    end
  end
end
