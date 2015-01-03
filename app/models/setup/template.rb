module Setup
  class Template
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include Setup::Enum
    include Trackable

    field :name, type: String

    belongs_to :library, class_name: Setup::Library.name
    has_many :connection_roles, class_name: Setup::ConnectionRole.name, inverse_of: :template
    has_many :flows, class_name: Setup::Flow.name, inverse_of: :template
  end
end
