module Setup
  class SharedName
    include CenitUnscoped
    include Trackable
    include CollectionName

    Setup::Models.exclude_actions_for self, :new, :edit, :translator_update, :convert, :send_to_flow, :delete_all, :delete

    BuildInDataType.regist(self).with(:name)

    has_and_belongs_to_many :owners, class_name: ::User.to_s, inverse_of: nil

    validates_uniqueness_of :name

    before_save do
      self.owners << creator unless owners.present?
    end
  end
end
