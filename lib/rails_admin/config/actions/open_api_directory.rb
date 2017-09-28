module RailsAdmin
  module Config
    module Actions

      class OpenApiDirectory < RailsAdmin::Config::Actions::Base

        register_instance_option :pjax? do
          true
        end

        register_instance_option :root do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do
            @dashboard_group_ref = 'connectors'
            @dashboard_group = dashboard_group(@dashboard_group_ref)
            @model_config = RailsAdmin.config(Setup::ApiSpec)
            @objects = list_apis
            if (id = params[:id])
              if (@object = @objects.first)
                if params[:fetch].to_b
                  if Account.current
                    object = @object['versions'][@object['preferred']]
                    @object = Setup::ApiSpec.create(url: object['swaggerUrl'] || object['swaggerYamlUrl'])
                    @abstract_model = @model_config.abstract_model
                    if @object.errors.present?
                      handle_save_error
                    else
                      redirect_to rails_admin.swagger_path(model_name: @abstract_model.to_param, id: @object.id.to_s)
                    end
                  else
                    warden.authenticate! scope: :user
                  end
                else
                  render :open_api_directory_show
                end
              else
                flash[:error] = "API with ID #{id} not found"
                params.delete(:id)
              end
            end
          end
        end

        register_instance_option :link_icon do
          'fa fa-cube'
        end
      end

    end
  end
end