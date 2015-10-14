module RailsAdmin
  module Config
    module Actions
      class LoadModel < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::Model
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :visible do
          authorized? && (obj = bindings[:object]) && !obj.loaded?
        end

        register_instance_option :controller do
          proc do

            if @object.loaded?
              flash[:notice] = "Model '#{@object.title}' is already loaded!"
            else
              begin
                @object.show_navigation_link = true
                @object.save
                report = @object.load_models(activated: true)
                RailsAdmin::AbstractModel.model_loaded(report[:loaded])
                if report[:model]
                  flash[:success] = "Model '#{@object.title}' loaded!"
                else
                  flash[:error] = ''.html_safe
                  report[:errors].each do |data_type, errors|
                    do_flash(:error, "<strong>Model '#{data_type.title}' could not be loaded</strong>", errors, reset: false)
                  end
                end
              rescue Exception => ex
                #raise ex
                flash[:error] = "Error loading model '#{@object.title}': #{ex.message}"
              end
            end
            redirect_to rails_admin.show_path(model_name: Setup::Model.to_s.underscore.gsub('/', '~'), id: @object.id)
          end
        end

        register_instance_option :link_icon do
          'icon-play-circle'
        end

        register_instance_option :pjax? do
          false
        end
      end
    end
  end
end