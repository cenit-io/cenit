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
            if shared_params = params.delete(shared_collection_config.abstract_model.param_key)
              sanitize_params_for!(:create, shared_collection_config, shared_params)
            end
            shared = false
            collection = Cenit::Actions.build_collection(@object || params.delete[:bulk_ids], @abstract_model.model_name)
            if params[:_restart].nil? && shared_params
              @shared_collection = Setup::SharedCollection.new(shared_params.to_hash.merge(image: collection.image))
              @shared_collection.source_collection = collection
              shared = params[:_share] && Cenit::Actions.store(@shared_collection)
            end
            if shared
              redirect_to back_or_index
            else
              @shared_collection ||= Setup::SharedCollection.new(image: collection.image, name: collection.name, source_collection: collection)
              @shared_collection.instance_variable_set(:@_selecting_connections, collection.connections.present? && (!shared_params || shared_params[:connection_ids].blank?))
              @shared_parameter_enum = @shared_collection.enum_for_pull_parameters
              @model_config = shared_collection_config
              if params[:_share] && @shared_collection.errors.present?
                do_flash(:error, t('admin.flash.error', name: @model_config.label, action: t("admin.actions.#{@action.key}.done").html_safe), @shared_collection.errors.full_messages)
              end
              render :share
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