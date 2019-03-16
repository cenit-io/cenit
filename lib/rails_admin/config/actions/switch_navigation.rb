module RailsAdmin
  module Config
    module Actions
      class SwitchNavigation < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::DataType.class_hierarchy
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :visible do
          authorized? && (obj = bindings[:object]) && obj.records_model.modelable?
        end

        register_instance_option :controller do
          proc do
            if @object.records_model.modelable?
              @object.navigation_link = !@object.navigation_link
              @object.save
              flash[:success] =
                if @object.navigation_link
                  "Data type #{@object.custom_title} added to navigation links"
                else
                  "Data type #{@object.custom_title} removed from navigation links"
                end
            else
              flash[:error] = "Model #{@object.title} is not an object model"
            end
            redirect_to rails_admin.show_path(model_name: @object.class.to_s.underscore.gsub('/', '~'), id: @object.id)
          end
        end

        register_instance_option :i18n_key do
          "#{key.to_s}.#{bindings[:object].navigation_link ? 'hide' : 'show'}"
        end

        register_instance_option :link_icon do
          bindings[:object].navigation_link ? 'fa fa-unlink' : 'fa fa-link'
        end

        register_instance_option :pjax? do
          false
        end

      end
    end
  end
end