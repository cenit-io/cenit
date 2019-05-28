module Setup
  LegacyTranslator.class_eval do
    include RailsAdmin::Models::Setup::LegacyTranslatorAdmin
  end
end
