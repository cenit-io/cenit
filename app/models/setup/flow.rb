module Setup
  class Flow
    include Mongoid::Document
    include Mongoid::Timestamps

    field :name, type: String
    field :purpose, type: String

    belongs_to :data_type, class_name: 'Setup::DataType'
    belongs_to :connection, class_name: 'Setup::Connection'
    belongs_to :webhook, class_name: 'Setup::Webhook'
    belongs_to :event, class_name: 'Setup::Event'

    validates_presence_of :name, :purpose, :data_type, :connection, :webhook, :event

    def process(object=nil)
      return if self.data_type != object.data_type
      message = {
        :object => {self.data_type.name => object},
        :url => "#{self.connection.url}/#{self.webhook.path}",
        :store => self.connection.store,
        :token => self.connection.token
      }.to_json
      Cenit::Middleware::Producer.send_to_rabbitmq(message)
    end

  end
end
