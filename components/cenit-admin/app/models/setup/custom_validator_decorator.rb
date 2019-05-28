module Setup
  CustomValidator.class_eval do
    include RailsAdmin::Models::Setup::CustomValidatorAdmin
  end
end
