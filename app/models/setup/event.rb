module Setup
  class Event
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include Trackable

    BuildInDataType.regist(self).with(:name).referenced_by(:name).and(sub_schema: "self['_type']")

    field :name, type: String
    field :last_trigger_timestamps, type: DateTime

    belongs_to :template, class_name: Setup::Template.name, inverse_of: :events

    validates_uniqueness_of :name

    before_save :do_not_save

    def do_not_save
      errors.add(:base, 'An event must be of type Observer or Scheduler')
      false
    end

  end
end
