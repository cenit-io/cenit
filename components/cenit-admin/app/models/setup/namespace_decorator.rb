module Setup
  Namespace.class_eval do
    include RailsAdmin::Models::Setup::NamespaceAdmin
  end
end
