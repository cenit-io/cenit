module Setup
  DataType.class_eval do
    include RailsAdmin::Models::Setup::DataTypeAdmin
  end
end
