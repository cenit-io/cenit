module RailsAdmin
  module RestApi
    module Notebooks
      ###
      # Setup all rest-api doc as notebooks.
      class Startup
        include RailsAdmin::RestApiHelper
        include RailsAdmin::RestApi::Notebooks

        def self.init
          ranb = self.new
          ranb.auto_create
        end

        def auto_create
          Setup::CenitDataType.all.each do |dt|
            @params = {}
            @data_type = dt
            @abstract_model = abstract_model_class
            @properties = @abstract_model.properties

            # Generate rest-api doc as notebook.
            api_langs.each { |lang| api_notebook(lang) if lang[:runnable] }
          end
        end

        def abstract_model_class
          model = @data_type.records_model
          model.is_a?(Class) ? RailsAdmin::AbstractModel.new(model) : RailsAdmin::MongoffAbstractModel.new(model)
        end
      end
    end
  end
end