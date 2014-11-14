
require 'open-uri'

module Setup
  class XmlSchema
    include Mongoid::Document
    include Mongoid::Timestamps

    field :uri, type: String
    field :schema, type: String
    field :sample_data, type: String

    validates_presence_of :uri, :schema

    before_save :validate_schema_and_sample

    def validate_schema_and_sample
      begin
        puts 'Parsing schema...'
        xsd = Nokogiri::XML::Schema(self.schema)
        puts 'Schema parsed!'
      rescue Exception => ex
        puts "ERROR: #{errors.add(:schema, ex.message).to_s}"
        return false
      end
      unless self.sample_data.blank?
        begin
          puts 'Parsing sample...'
          xml = Nokogiri::XML(self.sample_data)
          puts 'Validating sample...'
          xsd.validate(xml).each { |e| puts "ERROR: #{errors.add(:sample_data, e.to_s).to_s}" }
          puts 'Sample parsed and validated!'
        rescue Exception => ex
          puts "ERROR: #{errors.add(:sample_data, ex.message).to_s}"
        end
      end
      return errors.blank?
    end
  end
end