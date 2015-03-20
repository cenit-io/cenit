module Setup
  class Event
    include CenitScoped


    BuildInDataType.regist(self).with(:name).referenced_by(:name).and(sub_schema: "self['_type']")

    field :name, type: String
    field :last_trigger_timestamps, type: DateTime

    belongs_to :cenit_collection, class_name: Setup::Collection.to_s, inverse_of: :events

    validates_account_uniqueness_of :name

    before_save :do_not_save

    def do_not_save
      if self.is_a?(Setup::Observer) || self.is_a?(Setup::Scheduler)
        true
      else
        errors.add(:base, 'An event must be of type Observer or Scheduler')
        false
      end
    end

  end
end
