module Setup
  DataTypeGeneration.class_eval do
    include RailsAdmin::Models::Setup::DataTypeGenerationAdmin
  end
end
