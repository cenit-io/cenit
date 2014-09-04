module Setup
  class Notification
    include Mongoid::Document
    include Mongoid::Timestamps

    field :code, type: Integer
    field :reference, type: String
    field :message, type: String
    field :object, type: Hash

    belongs_to :webhook, :class_name => 'Setup::Webhook'
    belongs_to :connection, :class_name => 'Setup::Connection'

  end
end
