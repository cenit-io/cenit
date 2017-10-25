module RailsAdmin
  module Config
    module Actions
      class TraceIndex < RailsAdmin::Config::Actions::Base

        register_instance_option :authorization_key do
          :trace
        end

        register_instance_option :collection do
          true
        end

        register_instance_option :route_fragment do
          'trace'
        end

        register_instance_option :controller do
          proc do
            Thread.current["[cenit][#{Mongoid::Tracer::Trace}]:persistence-options"] = { model: @abstract_model.model }
            @model_config = RailsAdmin::Config.model(Mongoid::Tracer::Trace)
            @context_abstract_model = @model_config.abstract_model
            @objects = list_entries(@model_config, :trace)

            render :index
          end
        end

        register_instance_option :link_icon do
          'fa fa-code-fork'
        end
      end
    end
  end
end