module RailsAdmin
  module Config
    module Actions
      class SendToFlow < RailsAdmin::Config::Actions::Base

        register_instance_option :visible? do
          authorized? && !(@flows = Setup::Flow.where(:data_type => Setup::DataType.where(:name => bindings[:abstract_model].model_name).first).collect { |f| f }).blank?
        end

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do

            if params[:send_data]
              if flow_id = params[:flow_id]
                if flow = Setup::Flow.find_by(:id => flow_id) rescue nil
                  list_entries(@model_config, :send_to_flow).each do |model|
                    flow.process(model)
                  end
                  flash[:notice] = "Models were send to flow '#{flow.name}'"
                else
                  flash[:error] = "Flow with id '#{flow_id}' not found"
                end
              end
              redirect_to back_or_index
            else
              render @action.template_name
            end

          end
        end

        register_instance_option :bulkable? do
          true
        end

        register_instance_option :link_icon do
          'icon-share-alt'
        end
      end
    end
  end
end