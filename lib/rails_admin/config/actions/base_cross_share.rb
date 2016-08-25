module RailsAdmin
  module Config
    module Actions
      class BaseCrossShare < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          [
            Setup::OauthClient,
            Setup::Oauth2Scope,
            Setup::Scheduler,
            Setup::Algorithm,
            Setup::Webhook,
            Setup::Connection,
            Setup::Translator,
            Setup::Flow
          ] +
            Setup::BaseOauthProvider.class_hierarchy +
            Setup::DataType.class_hierarchy +
            Setup::Validator.class_hierarchy
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do
            render_form = true
            origin_config = RailsAdmin::Config.model(Forms::CrossOriginSelector)
            if (origin_data = params[origin_config.abstract_model.param_key]) && origin_data.permit! &&
              (@form_object = Forms::CrossOriginSelector.new(origin_data)).valid?
              model = @abstract_model.model
              criteria = model.all
              ids = params[:bulk_ids] || []
              ids << @object.id if @object
              if ids.present?
                criteria = criteria.any_in(id: ids)
              end
              if model < Trackable
                criteria = criteria.with_tracking
              end
              criteria.cross(origin_data['origin']) do |_, non_tracked_ids|
                if non_tracked_ids.present?
                  Account.each do |account| #TODO Run as a task in the background
                    if account == Account.current
                      model.clear_pins_for(account, non_tracked_ids)
                    else
                      model.clear_config_for(account, non_tracked_ids)
                    end
                  end
                end
              end
              render_form = false
            end
            if render_form
              @form_object ||= Forms::CrossOriginSelector.new
              @form_object.target_model = @abstract_model.model
              @model_config = origin_config
              if @form_object.errors.present?
                do_flash_now(:error, 'Error selecting origin', @form_object.errors.full_messages)
              end

              render :form
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