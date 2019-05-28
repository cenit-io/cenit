module Setup
  MappingConverter.class_eval do
    include RailsAdmin::Models::Setup::MappingConverterAdmin
  end
end
