module Setup
  PullImport.class_eval do
    include RailsAdmin::Models::Setup::PullImportAdmin
  end
end
