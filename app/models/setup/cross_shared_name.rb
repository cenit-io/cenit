module Setup
  class CrossSharedName
    include CenitUnscoped
    include CollectionName
    include ::RailsAdmin::Models::Setup::CrossSharedNameAdmin

    deny :all

    build_in_data_type.with(:name)

    has_and_belongs_to_many :owners, class_name: Cenit::MultiTenancy.user_model.name, inverse_of: nil

    validates_uniqueness_of :name
  end
end
