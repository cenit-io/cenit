module RailsAdmin
  module Config
    module Actions
      class BaseCross < RailsAdmin::Config::Actions::Base

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do
            render_form = true
            model = process_bulk_scope
            origin_config = RailsAdmin::Config.model(Forms::CrossOriginSelector)
            if (origin_data = params[origin_config.abstract_model.param_key]) && origin_data.permit! &&
              (@form_object = Forms::CrossOriginSelector.new(origin_data)).valid?
              do_flash_process_result Setup::Crossing.process(origin: @form_object.origin,
                                                              object_ids: @bulk_ids && @bulk_ids.collect(&:to_s),
                                                              data_type_id: model.data_type.id)
              render_form = false
            end
            if render_form
              @form_object ||= Forms::CrossOriginSelector.new
              @form_object.target_model = @abstract_model.model
              @model_config = origin_config
              if @form_object.errors.present?
                do_flash_now(:error, 'Error selecting origin', @form_object.errors.full_messages)
              end

              render :form, locals: { bulk_alert: true }
            else
              redirect_to back_or_index
            end
          end
        end

        register_instance_option :link_icon do
          'fa fa-exchange'
        end
      end
    end
  end
end