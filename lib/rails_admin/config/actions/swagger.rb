require 'yaml'
Psych.dump("foo")
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
            if params[:path].present?
              if params[:path] == 'editor'
                render template: 'rails_admin/main/swagger-editor', layout: false
              elsif params[:path] == 'editor/config/defaults'
                render json: swagger_config
              elsif params[:path] == 'spec'
                if request.get?
                  render template: 'rails_admin/main/swagger-spec.yml', layout: false, content_type: 'text/yaml'
                elsif request.put?
                  render text: 'success!'
                end
              else
                render :nothing => true, :status => 404
              end
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
