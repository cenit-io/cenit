require 'zip'

module RailsAdmin
  module Config
    module Actions
      class ImportSchema < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::Schema
        end

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do
            form_config = RailsAdmin::Config.model(Forms::ImportSchema)
            if params[:_save] && (message = params[form_config.abstract_model.param_key])
              do_flash_process_result Setup::SchemasImport.process(message)
              redirect_to back_or_index
            else
              @form_object = Forms::ImportSchema.new
              @model_config = form_config
              render :form
            end
          end
        end

        register_instance_option :link_icon do
          'icon-upload'
        end

        register_instance_option :pjax? do
          false
        end

      end
    end
  end
end