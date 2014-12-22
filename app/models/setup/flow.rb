require 'nokogiri'

module Setup
  class Flow
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include Setup::Enum
    include Trackable

    field :name, type: String
    field :purpose, type: String
    field :active, type: Boolean
    field :transformation, type: String
    field :last_trigger_timestamps, type: DateTime

    has_one :schedule, class_name: Setup::Schedule.name, inverse_of: :flow
    has_one :batch, class_name: Setup::Batch.name, inverse_of: :flow
    
    belongs_to :data_type, class_name: Setup::DataType.name
    belongs_to :connection, class_name: Setup::Connection.name
    belongs_to :webhook, class_name: Setup::Webhook.name
    belongs_to :event, class_name: Setup::Event.name



    validates_presence_of :name, :purpose, :data_type, :connection, :webhook, :event
    accepts_nested_attributes_for :schedule, :batch

    def process(object, notification_id=nil) 
      puts "Flow processing '#{object}' on '#{self.name}'..."

      unless !object.nil? && object.respond_to?(:data_type) && self.data_type == object.data_type && object.respond_to?(:to_xml)
        puts "Flow processing on '#{self.name}' aborted!"
        return
      end

      xml_document = Nokogiri::XML(object.to_xml)
      hash = Hash.from_xml(xml_document.to_s)
      if self.transformation && !self.transformation.empty?
        hash = Flow.transform(self.transformation, hash)
      else
        puts 'No transformation applied'
      end
      process_json_data(hash.to_json, notification_id)
      puts "Flow processing on '#{self.name}' done!"
    end

    def process_all
      model = data_type.model
      total = model.count
      puts "TOTAL: #{total}"
      
      per_batch = flow.batch.size rescue 1000
      0.step(model.count, per_batch) do |offset|
        model.limit(per_batch).skip(offset).each do |batch| 
          data = batch.map { |object| prepare(object) }
          process_batch(data) 
        end
      end
    rescue Exception => e
      puts "ERROR -> #{e.inspect}"
    end
    
    def prepare(object)
      xml_document = Nokogiri::XML(object.to_xml)
      Hash.from_xml(xml_document.to_s).values.first
    end  
      
    def process_batch(data)
      message = {
        :flow_id => self.id,
        :json_data => {data_type.model.name.downcase => data},
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
          :json_data => clean_json_data(json),
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

    def clean_json_data(json)
      cleaned_json = {}
      json.each do |k, v|
        new_key = Setup::DataType.find_by(id: k.slice(2, k.size)).name.downcase
        cleaned_json[new_key] = v
      end
      cleaned_json
    end

    def self.json_transform(template_hash, data_hash)
      template_hash.each do |key, value|
        if value.is_a?(String) && value =~ /\A\{\{[a-z]+(_|([0-9]|[a-z])+)*(.[a-z]+(_|([0-9]|[a-z])+)*)*\}\}\Z/
          new_value = data_hash
          value[2, value.length - 4].split('.').each do |k|
            next if new_value.nil? || !(template_hash = template_hash.is_a?(Hash) ? template_hash : nil) || new_value = new_value[k]
          end
          template_hash[key] = new_value
        elsif value.is_a?(Hash)
          template_hash[key] = json_transform(value, data_hash)
        end
      end
      return template_hash
    end

    def self.transform(transformation, document)
      document ||= {}
      puts "Transforming: #{document}"
      hash_document = nil
      begin
        template_hash = JSON.parse(transformation)
        puts 'JSON Transformation detected...'
        hash_document = json_transform(template_hash, hash_document = to_hash(document))
        puts 'JSON Transformation applied successfully!'
      rescue Exception => json_ex
        begin
          hash_document = Hash.from_xml(Nokogiri::XSLT(transformation).transform(to_xml_document(document)).to_s)
          puts 'XSLT Transformation detected...'
          puts 'XSLT Transformation applied successfully!'
        rescue Exception => xslt_ex
          puts 'ERROR applying transformation:'
          puts "\tJSON parser error: #{json_ex.message}"
          puts "\tXSLT parser error: #{xslt_ex.message}"
        end
      end
      puts "Transformation result: #{hash_document ? hash_document : document}"
      return hash_document || document
    end

    def self.to_hash(document)
      return document if document.is_a?(Hash)

      if (document.is_a?(Nokogiri::XML::Document))
        return Hash.from_xml(document.to_s)
      else
        begin
          return JSON.parse(document.to_s)
        rescue
          return Hash.from_xml(document.to_s) rescue {}
        end
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

      return Nokogiri::XML(document.to_xml)
    end
    
  end
end
