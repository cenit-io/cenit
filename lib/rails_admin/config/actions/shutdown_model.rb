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
          [:get, :post]
        end

        register_instance_option :visible do
          authorized? && bindings[:object].is_object? && bindings[:object].loaded?
        end

        register_instance_option :controller do
          proc do
            done = true
            if model = @object.model
              begin
                unless params[:shutdown]
                  report = Setup::DataType.shutdown(@object, report_only: true, shutdown_all: true)
                  @data_types = report[:destroyed].collect { |model| model.data_type }.uniq
                  params[:shutdown] = true if @data_types.size == 1
                end
                if params[:shutdown]
                  (report = Setup::DataType.shutdown(@object, shutdown_all: true))[:destroyed].each do |model|
                    (data_type = model.data_type).activated = data_type.show_navigation_link = false
                    data_type.save
                  end
                  flash[:success] = "Shutdown model #{@object.title} success"
                else
                  done = false
                  render @action.template_name
                end
              rescue Exception => ex
                flash[:error] = "Error shutdown model #{@object.title}: #{ex.message}"
              end
            else
              flash[:error] = "Model #{@object.title} is not loaded"
            end
            redirect_to rails_admin.show_path(model_name: Setup::DataType.to_s.underscore.gsub('/', '~'), id: @object.id) if done
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