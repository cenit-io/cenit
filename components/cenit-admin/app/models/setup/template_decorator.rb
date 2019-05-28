module Setup
  Template.class_eval do
    include RailsAdmin::Models::Setup::TemplateAdmin
  end
end
