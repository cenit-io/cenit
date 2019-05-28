module Setup
  Converter.class_eval do
    include RailsAdmin::Models::Setup::ConverterAdmin
  end
end
