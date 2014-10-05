module Hub
  module AfterSave
    extend ActiveSupport::Concern

    included do

      after_create do |object|
        object.find_events('created')
      end

      after_update do |object|
        object.find_events('updated')
      end

    end

    def data_type
      Setup::DataType.where(model: self.class.to_s).first
    end

    def find_events(action)
      basic_event = Setup::Event.where(name: action).first
      basic_event.throw(self) unless basic_event.nil?

      Setup::Event.where(data_type: self.data_type).each {|e| e.throw(self)}
    end

  end
end
