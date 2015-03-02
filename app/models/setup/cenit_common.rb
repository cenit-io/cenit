module Setup
  module CenitCommon
    extend ActiveSupport::Concern
    included do
      include Mongoid::Document
      include Mongoid::Timestamps
      include Mongoid::CenitExtension
      include Trackable
      include AccountScoped
    end
   
  end
end