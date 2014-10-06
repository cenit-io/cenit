module Setup
  class Event
    include Mongoid::Document
    include Mongoid::Timestamps
    include Setup::Enum

    field :name, type: String

    belongs_to :model_schema, class_name: 'Setup::ModelSchema'

    field :attr, type: String
    field :rule, type: String
    field :condition, type: String
    field :value, type: String

    validates_presence_of :name

    # TODO: eval object value before and now
    def apply(object=nil)
      return true unless self.attr.present?

      if self.rule == 'now present'
        return true if !object.send(self.attr).nil?
      elsif self.rule == 'no longer present'
        return true if object.send(self.attr).nil?
      elsif self.rule == 'has changed to a value'
        return eval [object.send(attr), self.condition, self.value].join(' ')
      end

      return false
    end

    def throw(object=nil)
      Setup::Flow.where(event: self).each {|f| f.process(object)} if apply(object)
    end

  end
end
