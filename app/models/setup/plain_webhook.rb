module Setup
  class PlainWebhook < Webhook
    include NamespaceNamed
    include CustomTitle
    include RailsAdmin::Models::Setup::PlainWebhookAdmin

    build_in_data_type.referenced_by(:namespace, :name).excluding(:connection_roles)

    field :path, type: String
    field :method, type: String, default: :post
    field :description, type: String

    parameters :parameters, :headers, :template_parameters

    validates_presence_of :path

  end
end
