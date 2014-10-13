module Setup
  class Flow < Base
    include Setup::Enum

    field :name, type: String
    field :purpose, type: String
    field :active, type: Boolean

    belongs_to :connection_webhook, class_name: 'Setup::ConnectionWebhook', inverse_of: :flow
    belongs_to :event, class_name: 'Setup::Event', inverse_of: :flow

    validates_presence_of :name, :purpose, :connection_webhook, :event
    
    validate do
      connection_webhook.model == event.model
    end 
    
    rails_admin do 
      field :purpose
      field :connection_webhook   
        
      field :event
      field :name
      field :active
    end  

    def process(object, notification_id=nil)
      return if connection_webhook.model != object.model_schema
      message = {
        flow_id: self.id,
        object_id: object.id,
        notification_id: notification_id
      }.to_json
      Cenit::Rabbit.send_to_rabbitmq(message)
    end

  end
end
