module Setup
  class Flow
    include Mongoid::Document
    include Mongoid::Timestamps
    include Setup::Enum

    field :name, type: String
    field :purpose, type: String

    belongs_to :model_schema, class_name: 'Setup::ModelSchema'
    belongs_to :connection, class_name: 'Setup::Connection'
    belongs_to :webhook, class_name: 'Setup::Webhook'
    belongs_to :event, class_name: 'Setup::Event'

    validates_presence_of :name, :purpose, :model_schema, :connection, :webhook, :event

    def process(object, notification_id=nil)
      return if self.model_schema != object.model_schema
      message = {
        :flow_id => self.id,
        :object_id => object.id,
        :notification_id => notification_id
      }.to_json
      Cenit::Rabbit.send_to_rabbitmq(message)
    end

  end
end
