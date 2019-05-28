module Setup
  Translation.class_eval do
    include RailsAdmin::Models::Setup::TranslationAdmin
  end
end
