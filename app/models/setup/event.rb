module Setup
  class Event
    include Mongoid::Document
    include Mongoid::Timestamps
    include Setup::Enum

    field :name, type: String

    belongs_to :data_type, class_name: 'Setup::DataType'

    field :attr, type: String
    field :rule, type: String
    field :condition, type: String
    field :value, type: String

    validates_presence_of :name

    # TODO: eval object value before and now
    # TODO: eval condition
    def apply(object=nil)
      return true if self.attr.nil?
      return true if self.rule == 'now_present' && !object.send(self.attr).nil?
      return true if self.rule == 'no_longer_present' && object.send(self.attr).nil?

      return false
    end

    def throw(object=nil)
      puts "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE"
      Setup::Flow.where(event: self).each {|f| f.process(object)} #if apply(object)
    end

  end
end
