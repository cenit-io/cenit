module Setup
  class Template
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include Setup::Enum
    include Trackable

    field :name, type: String

    belongs_to :library, class_name: Setup::Library.name
    belongs_to :connection_role, class_name: Setup::ConnectionRole.name
    has_and_belongs_to_many :webhooks, class_name: Setup::Webhook.name, inverse_of: :templates
    has_and_belongs_to_many :flows, class_name: Setup::Flow.name, inverse_of: :templates
  end
end
