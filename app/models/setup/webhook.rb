module Setup
  class Webhook
    include CustomTitle
    include ShareWithBindingsAndParameters
    include WebhookCommon
    include ClassHierarchyAware

    build_in_data_type.and_polymorphic(properties: {
      method: {
        enum: method_enum.map(&:to_s)
      }
    })
    abstract_class true
  end
end
