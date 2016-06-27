module RailsAdmin
  module Config
    module Actions
      class DeleteAll < RailsAdmin::Config::Actions::Base

        register_instance_option :visible? do
          authorized? && bindings[:controller].list_entries(bindings[:abstract_model].config, :destroy).size > 0
        end

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do

            model = @abstract_model.model rescue nil
            if model
              @model_label_plural =
                if (data_type = model.try(:data_type))
                  data_type.title.downcase.pluralize
                else
                  @abstract_model.pretty_name.downcase.pluralize
                end
              scope = list_entries(@abstract_model.config, :destroy)
              @total = scope.size
              if params[:delete]
                do_flash_process_result Setup::Deletion.process(model_name: model.to_s, selector: scope.selector)
                redirect_to back_or_index
              end
            else
              flash[:error] = 'Unknown model'
              redirect_to back_or_index
            end
          end
        end

        register_instance_option :link_icon do
          'icon-trash'
        end
      end
    end
  end
end