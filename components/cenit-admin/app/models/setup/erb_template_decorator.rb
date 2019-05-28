module Setup
  ErbTemplate.class_eval do
    include RailsAdmin::Models::Setup::ErbTemplateAdmin
  end
end
