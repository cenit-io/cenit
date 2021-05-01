class Role
  include Setup::CenitUnscoped

  build_in_data_type.with(:name, :metadata).on_origin(:admin)

  deny :all

  has_and_belongs_to_many :users
  belongs_to :resource, polymorphic: true

  field :name, type: String

  field :metadata

  index({
          name: 1,
          resource_type: 1,
          resource_id: 1
        },
        { unique: true })

  scopify

  before_destroy { %w(admin super_admin).exclude?(name) }

  DEFAULT_NAMES = %w(admin)
  FIRST_USER_DEFAULT_NAMES = %w(admin super_admin installer cross_shared)

  class << self

    def default_ids(first_user = false)
      (first_user ? FIRST_USER_DEFAULT_NAMES : DEFAULT_NAMES).map { |name| find_or_create_by(name: name) }.collect(&:id)
    end
  end
end
