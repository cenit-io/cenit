module RailsAdmin
  module Config
    module Actions

      class Share < RailsAdmin::Config::Actions::Base

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
            shared_collection_config = RailsAdmin::Config.model(Setup::CrossSharedCollection)
            if (shared_params = params.delete(shared_collection_config.abstract_model.param_key))
              sanitize_params_for!(:create, shared_collection_config, shared_params)
            end
            shared = false
            if params[:_restart].nil? && shared_params
              @form_object = Setup::CrossSharedCollection.new(shared_params.to_hash.merge(image: @object.image,
                                                                                          readme: @object.readme))
              shared = params[:_save] && @form_object.install(collection: @object)
            end
            if shared
              redirect_to back_or_index
            else
              @form_object ||= Setup::CrossSharedCollection.new(title: @object.title,
                                                                name: @object.name,
                                                                image: @object.image,
                                                                readme: @object.readme,
                                                                summary: (metadata = @object.metadata) &&
                                                                  (metadata = metadata['info']) &&
                                                                  (metadata['description'] || metadata['title']),
                                                                categories: (metadata && Setup::Category.where(:id.in => metadata['x-apisguru-categories'] || []) || []))
              @form_object.instance_variable_set(:@sharing, true)
              @model_config = shared_collection_config
              if params[:_save] &&
                (((@form_object.errors.present? && (msgs = @form_object.errors.full_messages))) ||
                  (@object.warnings.present? && (msgs = @object.warnings)))
                do_flash(:error, t('admin.flash.error', name: @model_config.label, action: t("admin.actions.#{@action.key}.done").html_safe), msgs)
              end
              render :form
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
