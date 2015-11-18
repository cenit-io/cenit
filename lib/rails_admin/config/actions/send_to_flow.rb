module RailsAdmin
  module Config
    module Actions
      class SendToFlow < RailsAdmin::Config::Actions::Base

        register_instance_option :visible? do
          if authorized?
            model = bindings[:abstract_model].model rescue nil
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

            @bulk_ids = params.delete(:bulk_ids)
            if object_ids = params.delete(:object_ids)
              @bulk_ids = object_ids
            end
            selector_config = RailsAdmin::Config.model(Forms::FlowSelector)
            render_form = true
            if model = @abstract_model.model rescue nil
              data_type_selector = model.data_type
              data_type_selector = nil if data_type_selector.is_a?(Setup::BuildInDataType)
              if select_data = params[selector_config.abstract_model.param_key]
                flow = Setup::Flow.where(id: select_data[:flow_id]).first
                if (@form_object = Forms::FlowSelector.new(flow: flow, data_type: data_type_selector)).valid?
                  begin
                    do_flash_process_result flow.process(object_ids: @bulk_ids)
                    render_form = false
                  rescue Exception => ex
                    flash[:error] = ex.message
                  end
                end
              end
            end
            if render_form
              @form_object ||= Forms::FlowSelector.new(data_type: data_type_selector)
              @model_config = selector_config
              if @form_object.errors.present?
                do_flash_now(:error, 'There are errors selecting the flow', @form_object.errors.full_messages)
              end

              render :form
            else
              redirect_to back_or_index
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
