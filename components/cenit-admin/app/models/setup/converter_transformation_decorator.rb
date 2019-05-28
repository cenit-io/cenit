module Setup
  ConverterTransformation.class_eval do
    include RailsAdmin::Models::Setup::ConverterTransformationAdmin
  end
end
