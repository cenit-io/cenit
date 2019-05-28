module Setup
  SmtpAccount.class_eval do
    include RailsAdmin::Models::Setup::SmtpAccountAdmin
  end
end
