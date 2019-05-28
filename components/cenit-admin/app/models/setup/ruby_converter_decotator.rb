module Setup
  RubyConverter.class_eval do
    include RailsAdmin::Models::Setup::RubyConverterAdmin
  end
end
