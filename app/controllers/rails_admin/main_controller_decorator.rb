module RailsAdmin
  MainController.class_eval do

    include GenerateCurlHelper
    include SwaggerHelper

  end
end