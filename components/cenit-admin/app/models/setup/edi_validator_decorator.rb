module Setup
  EdiValidator.class_eval do
    include RailsAdmin::Models::Setup::EdiValidatorAdmin
  end
end
