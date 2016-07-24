module RailsAdmin
  module Config
    module Actions

      class State < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::Task.class_hierarchy
        end

        register_instance_option :visible do
          authorized? && (obj = bindings[:object]) &&
            [
              Setup::PullImport
            ].include?(obj.class)
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :member do
          true
        end

        register_instance_option :controller do
          proc do
            handler_method = "#{request.method.to_s.downcase}_#{@object.class.to_s.split('::').last.underscore}"
            error_msg = nil
            if State.respond_to?(handler_method)
              begin
                State.send(handler_method, self, params, @object)
              rescue Exception => ex
                error_msg = ex.message
              end
            else
              error_msg = 'Not allowed action'
            end
            if error_msg
              flash[:error] = error_msg
              redirect_to back_or_index
            end
          end
        end

        register_instance_option :link_icon do
          'fa fa-question-circle'
        end

        register_instance_option :pjax? do
          false
        end

        class << self

          def get_pull_import(controller, params, task)
            controller.render :pull, locals: { pull_request: task.pull_request }
          end

          def post_pull_import(controller, params, task)
            task.retry if params[:_pull]
            controller.redirect_to controller.rails_admin.show_path(model_name: task.class.to_s.underscore.gsub('/', '~'), id: task.id.to_s)
          end
        end
      end
    end
  end
end