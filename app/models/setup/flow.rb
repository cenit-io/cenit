require 'nokogiri'

module Setup
  class Flow
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include Setup::Enum
    include Trackable

    field :name, type: String
    field :purpose, type: String, default: :send
    field :active, type: Boolean, default: :true
    field :transformation, type: String
    field :style, type: String
    field :last_trigger_timestamps, type: DateTime

    has_one :schedule, class_name: Setup::Schedule.name, inverse_of: :flow
    has_one :batch, class_name: Setup::Batch.name, inverse_of: :flow

    belongs_to :connection_role, class_name: Setup::ConnectionRole.name, inverse_of: :flow
    belongs_to :data_type, class_name: Setup::DataType.name, inverse_of: :flow
    belongs_to :webhook, class_name: Setup::Webhook.name, inverse_of: :flow
    belongs_to :event, class_name: Setup::Event.name, inverse_of: :flow
    belongs_to :transform, class_name: Setup::Transform.name, inverse_of: :flow
    
    has_and_belongs_to_many :templates, class_name: Setup::Template.name, inverse_of: :connection_roles

    validates_presence_of :name, :purpose, :data_type, :webhook, :event
    accepts_nested_attributes_for :schedule, :batch
    
    def style_enum
      %W(double_curly_braces xslt json.rabl xml.rabl xml.builder html.erb csv.erb js.erb text.erb html.haml)
    end

    def process(object, notification_id=nil)
      puts "Flow processing '#{object}' on '#{self.name}'..."

      unless object.present? && object.respond_to?(:data_type) && self.data_type == object.data_type
        puts "Flow processing on '#{self.name}' aborted!"
        return
      end

      process_json_data(object.to_json(include_root: true), notification_id)
      puts "Flow processing on '#{self.name}' done!"
    end

    def process_all
      model = data_type.model
      total = model.count
      puts "TOTAL: #{total}"

      per_batch = flow.batch.size rescue 1000
      0.step(model.count, per_batch) do |offset|
        data = model.limit(per_batch).skip(offset).map {|obj| obj.to_json(include_root: true)}
        process_batch(data)
      end
    rescue Exception => e
      puts "ERROR -> #{e.inspect}"
    end

    def process_batch(data)
      message = {
        :flow_id => self.id,
        :json_data => data,
        :notification_id => nil,
        :account_id => self.account.id
      }.to_json
      begin
        Cenit::Rabbit.send_to_rabbitmq(message)
      rescue Exception => ex
        puts "ERROR sending message: #{ex.message}"
      end
      puts "Flow processing json data on '#{self.name}' done!"
    end

    def process_json_data(json, notification_id=nil)
      puts "Flow processing json data on '#{self.name}'..."
      begin
        json = JSON.parse(json)
        puts json
      rescue
        puts "ERROR: invalid json data -> #{json}"
        return
      end
      message = {
          :flow_id => self.id,
          :json_data => json,
          :notification_id => notification_id,
          :account_id => self.account.id
      }.to_json
      begin
        Cenit::Rabbit.send_to_rabbitmq(message)
      rescue Exception => ex
        puts "ERROR sending message: #{ex.message}"
      end
      puts "Flow processing json data on '#{self.name}' done!"
      last_trigger_timestamps = Time.now
    end

    def self.transform(transformation, object, options = {})
      Setup::Transform.new(transformation: transformation, data_type: data_type, style: options[:style]).run(object, options)
    end

    def self.to_hash(document)
      return document if document.is_a?(Hash)
      return Hash.from_xml(document.to_s) if document.is_a?(Nokogiri::XML::Document)
        
      begin
        return JSON.parse(document.to_s)
      rescue
        return Hash.from_xml(document.to_s) rescue {}
      end
    end

    def self.to_xml_document(document)
      return document if document.is_a?(Nokogiri::XML::Document)

      unless document.is_a?(Hash)
        begin
          document = JSON.parse(document.to_s)
        rescue
          document = Hash.from_xml(document.to_s) rescue {}
        end
      end

      Nokogiri::XML(document.to_xml)
    end

  end
end
