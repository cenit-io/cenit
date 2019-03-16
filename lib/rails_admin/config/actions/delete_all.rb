module RailsAdmin
  module Config
    module Actions
      class DeleteAll < RailsAdmin::Config::Actions::Base

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:get, :delete]
        end

        register_instance_option :controller do
          proc do
            model = @abstract_model.model rescue nil
            if model
              scope = list_entries(@abstract_model.config, :destroy)
              @total = scope.size
              if request.delete?
                do_flash_process_result Setup::Deletion.process(model_name: model.to_s, selector: scope.selector)
                redirect_to back_or_index
              end
            else
              flash[:error] = 'Unknown model'
              redirect_to back_or_index
            end
          end
        end

        register_instance_option :bulk_processable? do
          true
        end

        register_instance_option :link_icon do
          'icon-trash'
        end
      end
    end
  end
end