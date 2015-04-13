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

  end
end
