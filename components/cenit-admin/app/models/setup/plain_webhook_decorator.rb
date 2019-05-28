module Setup
  PlainWebhook.class_eval do
    include RailsAdmin::Models::Setup::PlainWebhookAdmin
  end
end
