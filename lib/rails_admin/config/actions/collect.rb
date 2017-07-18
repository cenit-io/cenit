module RailsAdmin
  module Config
    module Actions
      class Collect < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::Namespace
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do
            selector_config = RailsAdmin::Config.model(Forms::CollectionSelector)
            if (attrs = params[selector_config.abstract_model.param_key])
              attrs.permit!
            else
              attrs = {}
            end
            @form_object = Forms::CollectionSelector.new(attrs)
            if request.post? && @form_object.valid?
              do_flash_process_result Setup::NamespaceCollection.process(collection_id: @form_object.collection_id.to_s,
                                                                         namespace: @object.name)
              redirect_to back_or_index
            else
              @model_config = selector_config
              render :form
            end
          end
        end

        register_instance_option :link_icon do
          'fa fa-cubes'
        end
      end
    end
  end
end