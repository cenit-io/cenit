module Setup
  class Webhook
    include ShareWithBindingsAndParameters
    include WebhookCommon
    include ClassHierarchyAware

    abstract_class true
  end
end
