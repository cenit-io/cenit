module RailsAdmin
  module Config
    module Actions
      class ShutdownModel < RailsAdmin::Config::Actions::Base

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
          authorized? && bindings[:object].is_object? &&  bindings[:object].activated && bindings[:object].loaded?
        end

        register_instance_option :controller do
          proc do
            if @object.activated
              if model = @object.model
                begin
                  @object.auto_load_model = @object.activated = @object.show_navigation_link = false
                  @object.save
                  Setup::Schema.shutdown_data_type_model(@object)
                  flash[:success] = "Shutdown model #{@object.name} success"
                rescue Exception => ex
                  flash[:error] = "Error shutdown model #{@object.name}: #{ex.message}"
                end
              else
                flash[:error] = "Model #{@object.name} is not loaded"
              end
            else
              flash[:notice] = "Model #{@object.name} is not activated"
            end
            redirect_to rails_admin.show_path(model_name: Setup::DataType.to_s.underscore, id: @object.id)
          end
        end

        register_instance_option :link_icon do
          'icon-off'
        end

        register_instance_option :pjax? do
          false
        end
      end
    end
  end
end