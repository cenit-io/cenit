module Setup
  class Flow < Base
    include Setup::Enum

    belongs_to :webhook, class_name: Setup::Webhook.name
    belongs_to :event, class_name: Setup::Event.name

    field :name, type: String
    field :purpose, type: String
    field :active, type: Boolean

    validates_presence_of :name, :purpose, :webhook, :event, :active
    
    validate do
      webhook.model == event.model
    end 
    
    rails_admin do
      field :name 
      field :purpose
      field :event
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
