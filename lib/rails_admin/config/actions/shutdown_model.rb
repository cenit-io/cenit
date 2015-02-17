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
          authorized? && bindings[:object] && bindings[:object].is_object? && bindings[:object].loaded?
        end

        register_instance_option :controller do
          proc do
            done = true
            if model = @object.model
              begin
                unless params[:shutdown]
                  report = Setup::DataType.shutdown(@object, report_only: true)
                  @shutdown = report[:destroyed].collect { |model| model.data_type }.uniq.select { |data_type| data_type != @object }
                  @reload = report[:affected].collect { |model| model.data_type }.uniq
                  params[:shutdown] = true if @shutdown.empty? && @reload.empty?
                end
                if params[:shutdown]
                  (report = Setup::DataType.shutdown(@object))[:destroyed].each do |model|
                    (data_type = model.data_type).activated = data_type.show_navigation_link = false
                    data_type.save
                  end
                  flash[:success] = "Model #{@object.title} is now shutdown"
                  unless report[:errors].empty?
                    flash[:error] = ''.html_safe
                    report[:errors].each do |data_type, errors|
                      flash[:error] += "<strong>Model #{data_type.title} could not be loaded</strong>".html_safe
                      flash[:error] += %(<br>- #{errors.full_messages.join('<br>- ')}<br>).html_safe
                    end
                  end
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