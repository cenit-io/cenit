class Role
  include Mongoid::Document
  include RailsAdmin::Models::RoleAdmin

  has_and_belongs_to_many :users
  belongs_to :resource, polymorphic: true

  field :name, type: String

  field :metadata

  index({
    name: 1,
    resource_type: 1,
    resource_id: 1
  },
  { unique: true})

  scopify

  before_destroy { %w(admin super_admin).exclude?(name) }
end
