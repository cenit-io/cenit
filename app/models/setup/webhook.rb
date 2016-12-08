module Setup
  class Webhook
    include ShareWithBindingsAndParameters
    include WebhookCommon
    include ClassHierarchyAware
    include RailsAdmin::Models::Setup::WebhookAdmin

    abstract_class true
  end
end
