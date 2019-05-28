module Setup
  Schema.class_eval do
    include RailsAdmin::Models::Setup::SchemaAdmin
  end
end
