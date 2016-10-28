module RailsAdmin
  module Config
    module Actions
      class Swagger < RailsAdmin::Config::Actions::Base
        RailsAdmin::Config::Actions.register(self)

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get, :put]
        end

        register_instance_option :controller do
          proc do
            if params[:show_editor].present?
              render template: 'rails_admin/main/swagger-editor', layout: false
            elsif params[:get_config].present?
              render json: swagger_config
            elsif request.get? # EDIT
              # TODO: Init swagger-editor with connection json.
            elsif request.put? # UPDATE
              # TODO: Update connection from swagger-editor json.
            end
          end
        end

        register_instance_option :link_icon do
          'icon-swagger'
        end

      end
    end
  end
end
