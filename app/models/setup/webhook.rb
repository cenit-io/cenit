module Setup
  class Webhook
    include Mongoid::Document
    include Mongoid::Attributes::Dynamic
    include Mongoid::Timestamps

    field :name, type: String
    field :path, type: String

    index({ starred: 1 })
  end
end
