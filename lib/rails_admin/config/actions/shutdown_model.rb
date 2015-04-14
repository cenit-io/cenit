module RailsAdmin
  module Config
    module Actions
      class ShutdownModel < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::Model
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :visible do
          authorized? && (data_type = bindings[:object]) && data_type.is_object? && data_type.activated && data_type.loaded?
        end

        register_instance_option :controller do
          proc do
            done = true
            if @object.is_object? && @object.activated && @object.loaded?
              begin
                unless params[:shutdown]
                  report = Setup::DataType.shutdown(@object, report_only: true)
                  @shutdown = report[:destroyed].collect(&:data_type).uniq.select { |data_type| data_type != @object }
                  @object.instance_variable_set(:@_to_reload, reload = report[:affected].collect(&:data_type).uniq)
                  params[:shutdown] = true if @shutdown.empty? && reload.empty?
                end
                if params[:shutdown]
                  @object.activated = ok = false
                  (report = Setup::DataType.shutdown(@object))[:destroyed].each do |model|
                    (data_type = model.data_type).activated = data_type.show_navigation_link = false
                    data_type.save
                    ok = ok || data_type == @object
                  end
                  flash[:success] = ok ? "Model '#{@object.title}' is now shutdown" : "Model' #{@object.title}' was not shutdown"
                  if report[:errors].present?
                    flash[:error] = ''.html_safe
                    report[:errors].each do |data_type, errors|
                      flash[:error] += "<strong>Model '#{data_type.title}' could not be loaded</strong>".html_safe
                      flash[:error] += %(<br>- #{errors.full_messages.join('<br>- ')}<br>).html_safe
                    end
                  end
                else
                  done = false
                  render @action.template_name
                end
              rescue Exception => ex
                raise ex
                flash[:error] = "Error shutdown model '#{@object.title}': #{ex.message}"
              end
            else
              flash[:error] = "Can not explicitly shutdown model '#{@object.title}'"
            end
            redirect_to rails_admin.show_path(model_name: Setup::Model.to_s.underscore.gsub('/', '~'), id: @object.id) if done
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