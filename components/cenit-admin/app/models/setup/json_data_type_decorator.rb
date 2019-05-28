module Setup
  JsonDataType.class_eval do
    include RailsAdmin::Models::Setup::JsonDataTypeAdmin
  end
end
