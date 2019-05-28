module Setup
  CallLink.class_eval do
    include RailsAdmin::Models::Setup::CallLinkAdmin
  end
end
