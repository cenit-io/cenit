module Setup
  class Flow
    include Mongoid::Document
    include Mongoid::Timestamps
    include Setup::Enum

    field :name, type: String
    field :purpose, type: String

    belongs_to :data_type, class_name: 'Setup::DataType'
    belongs_to :connection, class_name: 'Setup::Connection'
    belongs_to :webhook, class_name: 'Setup::Webhook'
    belongs_to :event, class_name: 'Setup::Event'

    validates_presence_of :name, :purpose, :data_type, :connection, :webhook, :event

    def process(object=nil)
      puts "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC"
      return if self.data_type != object.data_type
      puts "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD"
      message = {
        :object => {self.data_type.name => object},
        :url => "#{self.connection.url}/#{self.webhook.path}",
        :store => self.connection.store,
        :token => self.connection.token,
        :purpose => self.purpose
      }.to_json
      Cenit::Rabbit.send_to_rabbitmq(message)
    end

  end
end
