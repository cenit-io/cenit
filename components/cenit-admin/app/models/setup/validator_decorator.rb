module Setup
  Validator.class_eval do
    include RailsAdmin::Models::Setup::ValidatorAdmin
  end
end
