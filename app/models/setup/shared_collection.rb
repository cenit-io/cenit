module Setup
  class SharedCollection
    include CenitUnscoped

    Setup::Models.exclude_actions_for self, :new

    field :name, type: String
    field :description, type: String
    field :data, type: String

    validates_presence_of :name, :description

    validates_uniqueness_of :name
  end
end
