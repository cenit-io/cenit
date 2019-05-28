module Setup
  FileStoreConfig.class_eval do
    include RailsAdmin::Models::Setup::FileStoreConfigAdmin
  end
end
