module Setup
  Webhook.class_eval do
    include RailsAdmin::Models::Setup::WebhookAdmin
  end
end
