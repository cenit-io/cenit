module Setup
  class Event
    include CenitScoped
    include NamespaceNamed

    Setup::Models.exclude_actions_for self

    BuildInDataType.regist(self).with(:name).referenced_by(:namespace, :name)

    field :last_trigger_timestamps, type: DateTime

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
