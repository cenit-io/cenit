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
            shared = false

            shared_collection_config = RailsAdmin::Config.model(Setup::SharedCollection)
            if shared_params = params[shared_collection_config.abstract_model.param_key]
              @shared_collection = Setup::SharedCollection.new(shared_params.to_hash.merge(data: @object.to_json))
              shared = @shared_collection.save
            end
            if shared
              redirect_to back_or_index
            else
              @shared_parameter_enum = Setup::SharedCollection.pull_parameters_enum_for(@object)
              @shared_collection ||= Setup::SharedCollection.new(name: @object.name, data: @object.to_json)
              @model_config = shared_collection_config
              if @shared_collection.errors.present?
                flash.now[:error] = t('admin.flash.error', name: @model_config.label, action: t("admin.actions.#{@action.key}.done").html_safe).html_safe
                flash.now[:error] += %(<br>- #{@object.errors.full_messages.join('<br>- ')}).html_safe
              end
            end
          end
        end

        register_instance_option :link_icon do
          'icon-share'
        end

        register_instance_option :pjax? do
          true
        end
      end

    end
  end
end