module Setup
  FileDataType.class_eval do
    include RailsAdmin::Models::Setup::FileDataTypeAdmin
  end
end
