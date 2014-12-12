module RailsAdmin
  module Config
    module Actions
      class SwitchNavigation < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::DataType
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :visible do
          authorized? && bindings[:object].loaded?
        end

        register_instance_option :controller do
          proc do
            if model = @object.model
              @object.show_navigation_link = !@object.show_navigation_link
              @object.save
              RailsAdmin::AbstractModel.reset_models(model)
              if @object.show_navigation_link
                flash[:success] = "Model #{@object.name} added to navigation links"
              else
                flash[:success] = "Model #{@object.name} removed from navigation links"
              end
            else
              flash[:success] = "Model #{@object.name} is not loaded"
            end
            redirect_to rails_admin.show_path(model_name: Setup::DataType.to_s.underscore, id: @object.id)
          end
        end

        register_instance_option :i18n_key do
          "#{key.to_s}.#{bindings[:object].show_navigation_link ? 'hide' : 'show'}"
        end

        register_instance_option :link_icon do
          bindings[:object].show_navigation_link ? 'icon-eye-close' : 'icon-eye-open'
        end

        register_instance_option :pjax? do
          false
        end

      end

    end
  end
end