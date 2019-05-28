module Setup
  SmtpProvider.class_eval do
    include RailsAdmin::Models::Setup::SmtpProviderAdmin
  end
end
