module Setup
  class SharedName
    include CenitUnscoped
    include Trackable
    include CollectionName
    include RailsAdmin::Models::Setup::SharedNameAdmin

    deny :all

    build_in_data_type.with(:name)

    has_and_belongs_to_many :owners, class_name: ::User.to_s, inverse_of: nil

    validates_uniqueness_of :name

    before_save do
      self.owners << creator unless owners.present?
    end
  end
end
