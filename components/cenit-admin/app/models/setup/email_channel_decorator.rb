module Setup
  EmailChannel.class_eval do
    include RailsAdmin::Models::Setup::EmailChannelAdmin
  end
end
