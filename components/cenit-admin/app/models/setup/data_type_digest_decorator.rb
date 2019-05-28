module Setup
  DataTypeDigest.class_eval do
    include RailsAdmin::Models::Setup::DataTypeDigestAdmin
  end
end
