module Setup
  RubyTemplate.class_eval do
    include RailsAdmin::Models::Setup::RubyTemplateAdmin
  end
end
