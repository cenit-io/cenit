module Setup
  DataImport.class_eval do
    include RailsAdmin::Models::Setup::DataImportAdmin
  end
end
