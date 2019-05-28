module Setup
  DelayedMessage.class_eval do
    include RailsAdmin::Models::Setup::DelayedMessageAdmin
  end
end
