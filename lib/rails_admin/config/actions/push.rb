module RailsAdmin
  module Config
    module Actions
      class Push < RailsAdmin::Config::Actions::Base

        register_instance_option :visible do
          authorized? && (obj = bindings[:object]) &&
            begin
              criteria = { name: obj.name }
              criteria[:origin] = :owner unless Tenant.current_super_admin?
              Setup::CrossSharedCollection.where(criteria).exists?
            end
        end
        register_instance_option :only do
          Setup::Collection
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do

            form_config = RailsAdmin::Config.model(Forms::SharedCollectionSelector)
            done = false
            if (data = params[form_config.abstract_model.param_key]) && data.permit! &&
              (@form_object = Forms::SharedCollectionSelector.new(data)).valid?
              begin
                do_flash_process_result Setup::Push.process(source_collection_id: @object.id,
                  shared_collection_id: @form_object.shared_collection_id)
                done =true
              rescue Exception => ex
                flash[:error] = ex.message
              end
            end
            if done
              redirect_to back_or_index
            else
              @form_object ||= Forms::SharedCollectionSelector.new
              @form_object.criteria = { name: @object.name }
              @form_object.criteria[:origin] = :owner unless Tenant.current_super_admin?
              @model_config = form_config
              if @form_object.errors.present?
                do_flash(:error, 'There are errors in the push target specification', @form_object.errors.full_messages)
              end
              render :form
            end
          end
        end
        register_instance_option :link_icon do
          'icon-arrow-up'
        end
      end
    end
  end
end