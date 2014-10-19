module Setup
  class Flow < Base
    include Setup::Enum

    field :name, type: String
    field :purpose, type: String
    field :active, type: Boolean

    belongs_to :connection, class_name: 'Setup::Connection', inverse_of: :flows
    belongs_to :webhook, class_name: 'Setup::Webhook'
    belongs_to :event, class_name: 'Setup::Event'

    validates_presence_of :name, :purpose, :webhook, :connection, :event, :active
    
    validate do
      webhook.model == event.model
    end 
    
    rails_admin do
      field :name 
      field :purpose
      field :event
      field :connection
      field :webhook
      field :active
    end  

    def process(object, notification_id=nil)
      return if webhook.model != object.model_schema
      message = {
        flow_id: self.id,
        object_id: object.id,
        notification_id: notification_id
      }.to_json
      Cenit::Rabbit.send_to_rabbitmq(message)
    end

  end
end
