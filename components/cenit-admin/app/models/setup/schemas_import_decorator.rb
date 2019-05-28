module Setup
  SchemasImport.class_eval do
    include RailsAdmin::Models::Setup::SchemasImportAdmin
  end
end
