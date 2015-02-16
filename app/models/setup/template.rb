module Setup
  class Template
    include Mongoid::Document
    include Mongoid::Timestamps
    include AccountScoped
    include Setup::Enum
    include Trackable

    BuildInDataType.regist(self).embedding(:translators, :events)

    field :name, type: String

    has_many :libraries, class_name: Setup::Library.name, inverse_of: :template
    has_many :translators, class_name: Setup::Translator.name, inverse_of: :template
    has_many :events, class_name: Setup::Event.name, inverse_of: :template
    # belongs_to :connection_role, class_name: Setup::ConnectionRole.name
    # has_and_belongs_to_many :webhooks, class_name: Setup::Webhook.name, inverse_of: :templates
    # has_and_belongs_to_many :flows, class_name: Setup::Flow.name, inverse_of: :templates

    rails_admin do
      navigation_label 'Setup'
      weight -16
      # configure :webhooks do
      #   nested_form false
      # end
      # configure :flows do
      #   nested_form false
      # end
      show do
        field :name
        field :library
        field :translators
        field :events
        # field :connection_role
        # field :webhooks
        # field :flows

        field :_id
        field :created_at
        field :creator
        field :updated_at
        field :updater
      end
      fields :name, :libraries, :translators, :events#, :connection_role, :webhooks, :flows
    end
  end
end
