module RailsAdmin
  module Config
    module Actions

      class BaseShare < RailsAdmin::Config::Actions::Base

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do

            shared_collection_config = RailsAdmin::Config.model(Setup::SharedCollection)
            if (shared_params = params.delete(shared_collection_config.abstract_model.param_key))
              sanitize_params_for!(:create, shared_collection_config, shared_params)
            end
            shared = false
            @bulk_ids = params.delete(:bulk_ids)
            collection = Cenit::Actions.build_collection(@object || @bulk_ids, @abstract_model.model_name)
            if params[:_restart].nil? && shared_params
              @form_object = Setup::SharedCollection.new(shared_params.to_hash.merge(image: collection.image))
              @form_object.source_collection = collection
              shared = params[:_save] && Cenit::Actions.store(@form_object)
            end
            if shared
              redirect_to back_or_index
            else
              @form_object ||= Setup::SharedCollection.new(image: collection.image, name: collection.name, source_collection: collection)
              @form_object.instance_variable_set(:@_selecting_connections, collection.connections.present? && (!shared_params || params[:_restart]))
              @form_object.instance_variable_set(:@_selecting_dependencies, !shared_params || params[:_restart])
              @form_object.instance_variable_set(:@sharing, true)
              @model_config = shared_collection_config
              if params[:_save] && @form_object.errors.present?
                do_flash(:error, t('admin.flash.error', name: @model_config.label, action: t("admin.actions.#{@action.key}.done").html_safe), @form_object.errors.full_messages)
              end
              render :form
            end
          end
        end

        register_instance_option :link_icon do
          'icon-share'
        end

        register_instance_option :pjax? do
          false
        end
      end

    end
  end
end