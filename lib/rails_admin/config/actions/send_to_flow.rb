module RailsAdmin
  module Config
    module Actions
      class SendToFlow < RailsAdmin::Config::Actions::Base

        register_instance_option :visible? do
          if authorized?
            begin
              bindings[:abstract_model].model.data_type.present?
            rescue
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
          [:get, :post, :patch]
        end

        register_instance_option :controller do
          proc do
            Forms::FlowSelector.collection.drop
            model = process_bulk_scope
            selector_config = RailsAdmin::Config.model(Forms::FlowSelector)
            render_form = true
            if model
              data_type = model.data_type
              if (select_data = params[selector_config.abstract_model.param_key])
                flow = Setup::Flow.where(id: select_data[:flow_id]).first
                if (@form_object = Forms::FlowSelector.new(
                  flow: flow,
                  data_type: data_type)).valid?
                  begin
                    do_flash_process_result flow.process(
                      object_ids: @bulk_ids,
                      data_type_id: data_type.id.to_s)
                    render_form = false
                  rescue Exception => ex
                    flash[:error] = ex.message
                  end
                end
              end
            end
            if render_form
              @form_object ||= Forms::FlowSelector.new(data_type: data_type)
              @model_config = selector_config
              if @form_object.errors.present?
                do_flash_now(:error, 'There are errors selecting the flow', @form_object.errors.full_messages)
              end
              @form_object.save(validate: false)
              render :form, locals: { bulk_alert: true }
            else
              redirect_to back_or_index
            end
          end
        end

        register_instance_option :bulkable? do
          true
        end

        register_instance_option :bulk_processable? do
          true
        end

        register_instance_option :link_icon do
          'icon-share-alt'
        end
      end
    end
  end
end
