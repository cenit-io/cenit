module Setup
  class Connection
    include Mongoid::Document
    include Mongoid::Attributes::Dynamic
    include Mongoid::Timestamps

    field :name, type: String
    field :url, type: String

    field :store, type: String
    field :token, type: String

    index({ starred: 1 })
  end
end
