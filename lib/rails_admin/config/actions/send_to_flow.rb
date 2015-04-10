module RailsAdmin
  module Config
    module Actions
      class SendToFlow < RailsAdmin::Config::Actions::Base

        register_instance_option :visible? do
          if authorized?
            model = bindings[:abstract_model].model_name.constantize rescue nil
            if model.present? && model.respond_to?(:data_type)
              data_type = model.data_type
              #TODO Set send to flow action visible only if there is a flow
              #data_type && !(@flows = Setup::Flow.where(data_type: data_type).collect { |f| f }).blank?
              data_type.present?
            else
              false
            end
          else
            false
          end
        end

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do

            @bulk_ids = params[:bulk_ids]

            if params[:send_data]
              if (flow_id = params[:flow_id]).present?
                if (flow = Setup::Flow.where(id: flow_id).first).present?
                  flow.process(object_ids: @bulk_ids)
                  flash[:notice] = "Models were send to flow '#{flow.name}'"
                else
                  flash[:error] = "Flow with id '#{flow_id}' not found"
                end
              end
              redirect_to back_or_index
            else
              @flow_options = []
              model = @abstract_model.model_name.constantize rescue nil
              if model.present? && model.respond_to?(:data_type)
                model_data_type = model.data_type
                flows = Setup::Flow.all.select { |flow| flow.translator.type != :Import && flow.data_type == model_data_type }
                @flow_options = flows.collect { |f| [f.name, f.id] }
              end
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
