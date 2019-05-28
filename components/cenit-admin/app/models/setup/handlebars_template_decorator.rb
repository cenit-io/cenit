module Setup
  HandlebarsTemplate.class_eval do
    include RailsAdmin::Models::Setup::HandlebarsTemplateAdmin
  end
end
