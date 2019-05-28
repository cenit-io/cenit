module Setup
  Translator.class_eval do
    include RailsAdmin::Models::Setup::TranslatorAdmin
  end
end
