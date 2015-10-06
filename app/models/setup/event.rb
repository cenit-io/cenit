module Setup
  class Event
    include CenitScoped

    Setup::Models.exclude_actions_for self

    BuildInDataType.regist(self).with(:name).referenced_by(:name)

    field :name, type: String
    field :last_trigger_timestamps, type: DateTime

    validates_uniqueness_of :name

    before_save :check_instance_type

    def check_instance_type
      if self.is_a?(Setup::Observer) || self.is_a?(Setup::Scheduler)
        true
      else
        errors.add(:base, 'An event must be of type Observer or Scheduler')
        false
      end
    end

  end
end
