module RailsAdmin
  MainController.class_eval do

    include RestApiHelper
    include SwaggerHelper

  end
end