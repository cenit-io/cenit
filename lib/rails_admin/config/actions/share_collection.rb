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
            if params[:_restart].nil? && (shared_params = params[shared_collection_config.abstract_model.param_key])
              @shared_collection = Setup::SharedCollection.new(shared_params.to_hash.merge(image: @object.image))
              shared = @shared_collection.save if params[:_share]
            end
            if shared
              redirect_to back_or_index
            else
              @shared_collection ||= Setup::SharedCollection.new(image: @object.image, name: @object.name, source_collection: @object)
              @shared_collection.instance_variable_set(:@_selecting_connections, @object.connections.present? && (!shared_params || shared_params[:connection_ids].blank?))
              @shared_parameter_enum = @shared_collection.enum_for_pull_parameters
              @model_config = shared_collection_config
              if params[:_share] && @shared_collection.errors.present?
                flash.now[:error] = t('admin.flash.error', name: @model_config.label, action: t("admin.actions.#{@action.key}.done").html_safe).html_safe
                flash.now[:error] += %(<br>- #{@shared_collection.errors.full_messages.join('<br>- ')}).html_safe
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