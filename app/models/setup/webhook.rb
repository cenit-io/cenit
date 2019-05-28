module Setup
  class Webhook
    include CustomTitle
    include ShareWithBindingsAndParameters
    include WebhookCommon
    include ClassHierarchyAware

    abstract_class true
  end
end
