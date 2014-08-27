module Setup
  class Flow
    include Mongoid::Document
    include Mongoid::Attributes::Dynamic
    include Mongoid::Timestamps

    field :name, type: String
    field :send_or_receive, type: String
    field :model, type: String
    field :action, type: String

    belongs_to :webhook, class_name: 'Setup::Webhook'
    belongs_to :connection, class_name: 'Setup::Connection'

    index({ starred: 1 })

    def process(object=nil)
      message = {
        :object => {self.model => object},
        :url => "#{self.connection.url}/#{self.webhook.path}",
        :store => self.connection.store,
        :token => self.connection.token
      }.to_json
      Cenit::Middleware::Producer.send_to_rabbitmq(message)
    end

  end
end
