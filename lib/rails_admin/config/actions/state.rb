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
              Setup::PullImport,
              Setup::SharedCollectionPull,
              Setup::ApiPull
            ].include?(obj.class)
        end

        register_instance_option :http_methods do
          [:get, :post, :patch]
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

          def get_base_pull(controller, params, task)
            locals = { pull_request: task.pull_request_hash }
            if task.ask_for_install?
              locals[:before_form_partials] = :install_option
              locals[:pull_anyway] = ::User.current_installer?
            end
            locals[:shared_collection] = task.source_shared_collection
            controller.render :pull, locals: locals
          end

          def post_base_pull(controller, params, task)
            if params[:_pull]
              task.message[:install] = params[:install].to_b if task.ask_for_install?
              if (pull_parameters = params[:pull_parameters]).is_a?(Hash)
                pull_parameters.permit!
              else
                pull_parameters = {}
              end
              if (shared_collection = task.source_shared_collection)
                RailsAdmin::Config.model(shared_collection.pull_model).edit.fields.each { |field| field.parse_input(pull_parameters) }
                pull_parameters = shared_collection.pull_model.new(pull_parameters).share_hash
              end
              task.message[:pull_parameters] = pull_parameters
              task.retry
            end
            controller.redirect_to controller.rails_admin.show_path(model_name: task.class.to_s.underscore.gsub('/', '~'), id: task.id.to_s)
          end

          def patch_base_pull(controller, params, task)
            post_base_pull(controller, params, task)
          end

          def get_pull_import(controller, params, task)
            get_base_pull(controller, params, task)
          end

          def post_pull_import(controller, params, task)
            post_base_pull(controller, params, task)
          end

          def patch_pull_import(controller, params, task)
            post_base_pull(controller, params, task)
          end

          def get_shared_collection_pull(controller, params, task)
            get_base_pull(controller, params, task)
          end

          def post_shared_collection_pull(controller, params, task)
            post_base_pull(controller, params, task)
          end

          def patch_shared_collection_pull(controller, params, task)
            post_base_pull(controller, params, task)
          end

          def get_api_pull(controller, params, task)
            get_base_pull(controller, params, task)
          end

          def post_api_pull(controller, params, task)
            post_base_pull(controller, params, task)
          end

          def patch_api_pull(controller, params, task)
            post_base_pull(controller, params, task)
          end
        end
      end
    end
  end
end