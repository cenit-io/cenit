module Setup
  class Event < Base
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

      result = case self.rule
      when 'now present'
        !object.send(self.attr).nil?
      when 'no longer present'
        object.send(self.attr).nil?
      when 'has changed to a value'
        eval [object.send(attr), self.condition, self.value].join(' ')
      end
      
      return result
    end

    def throw(object=nil)
      Setup::Flow.where(event: self).each {|f| f.process(object)} if apply(object)
    end

  end
end
