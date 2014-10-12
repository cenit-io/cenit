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

  def model_schema
    model_name = self.class.to_s.split('::').last
    Setup::ModelSchema.where(name: model_name).first
  end

  def find_events(action)
    basic_event = Setup::Event.find_by(name: action)
    basic_event.throw(self) unless basic_event.nil?

    Setup::Event.where(model: self.model_schema).each {|e| e.throw(self)}
  end

end
