module RailsAdmin
  module Config
    module Actions
      HistoryIndex.class_eval do

        register_instance_option :listing? do
          true
        end


        register_instance_option :controller do
          proc do
            Thread.current["[cenit][#{HistoryTracker}]:persistence-options"] = { model: @abstract_model.model }
            @model_config = RailsAdmin::Config.model(HistoryTracker)
            @context_abstract_model = @model_config.abstract_model
            @objects = list_entries(@model_config, :history)

            render :index
          end
        end
      end
    end
  end
end
