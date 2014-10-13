module Setup
  class ConnectionWebhook < Base
    include Setup::Enum

    belongs_to :connection, class_name: 'Setup::Connection', inverse_of: :connection_webhooks 
    belongs_to :webhook, class_name: 'Setup::Webhook', inverse_of: :connection_webhooks
    has_one :flow, class_name: 'Setup::Flow', inverse_of: :connection_webhook
    
    accepts_nested_attributes_for :flow
    
    validates_presence_of :connection, :webhook
    
    field :partial, type: String

    rails_admin do

      field :connection     
      field :webhook
      field :partial do
        help 'optional partial schema for add params, validations, etc '
      end
      field :flow
      
      object_label_method do
        :name
      end
      
    end
    
    def flow_id
      self.flow.try :id
    end
    
    def flow_id=(id)
      self.flow = Flow.find_by_id(id)
    end 
    
    private
    
      def name
        "#{webhook.name} to #{connection.name}"
      end
    
      def model
        webhook.model
      end
    
      def path
        webhook.model
      end
    
      def purpose
        webhook.model
      end  

  end
end
