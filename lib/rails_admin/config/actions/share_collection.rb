module RailsAdmin
  module Config
    module Actions

      class ShareCollection < RailsAdmin::Config::Actions::Base

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
            collection = @object
            @object = nil
            shared = false

            shared_collection_config = RailsAdmin::Config.model(Setup::SharedCollection)
            if (shared_params = params[shared_collection_config.abstract_model.param_key]).present?
              @object = Setup::SharedCollection.new(shared_params.to_hash)
              @object.data = collection.to_json
              shared = @object.save
            end
            if shared
              redirect_to back_or_index
            else
              @object ||= Setup::SharedCollection.new(name: collection.name)
              @model_config = shared_collection_config
              if @object.errors.present?
                flash.now[:error] = t('admin.flash.error', name: @model_config.label, action: t("admin.actions.#{@action.key}.done").html_safe).html_safe
                flash.now[:error] += %(<br>- #{@object.errors.full_messages.join('<br>- ')}).html_safe
              end
            end
          end
        end

        register_instance_option :link_icon do
          'icon-share'
        end
      end

    end
  end
end