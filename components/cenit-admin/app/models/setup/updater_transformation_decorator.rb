module Setup
  UpdaterTransformation.class_eval do
    include RailsAdmin::Models::Setup::UpdaterTransformationAdmin
  end
end
