module Setup
  class SharedName
    include CenitUnscoped
    include Trackable

    Setup::Models.exclude_actions_for self, :new, :edit, :translator_update, :convert, :send_to_flow, :delete_all, #TODO :delete

    BuildInDataType.regist(self)

    field :name, type: String
    has_and_belongs_to_many :owners, class_name: ::User.to_s, inverse_of: nil

    validates_presence_of :name
    validates_uniqueness_of :name

    before_save do
      self.owners << creator unless owners.present?
    end
  end
end
