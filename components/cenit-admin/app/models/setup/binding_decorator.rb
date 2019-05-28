module Setup
  Binding.class_eval do
    include RailsAdmin::Models::Setup::BindingAdmin
  end
end
