module Setup
  class Template
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include Setup::Enum
    include Trackable

    BuildInDataType.regist(self).embedding(:translators, :events, :connection_roles, :webhooks)

    field :name, type: String

    has_many :libraries, class_name: Setup::Library.name, inverse_of: :template
    has_many :translators, class_name: Setup::Translator.name, inverse_of: :template
    has_many :events, class_name: Setup::Event.name, inverse_of: :template
    has_many :connection_roles, class_name: Setup::ConnectionRole.name, inverse_of: :template
    has_many :webhooks, class_name: Setup::Webhook.name, inverse_of: :template
    has_many :flows, class_name: Setup::Flow.name, inverse_of: :template

    rails_admin do
      navigation_label 'Setup'
      weight -16
      show do
        field :name
        field :library
        field :translators
        field :events
        field :connection_roles
        field :webhooks
        field :flows

        field :_id
        field :created_at
        field :creator
        field :updated_at
        field :updater
      end
      fields :name, :libraries, :translators, :events, :connection_roles, :webhooks, :flows
    end
  end
end
