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

            if model = @abstract_model.model rescue nil
              @model_label_plural =
                if data_type = model.try(:data_type)
                  data_type.title.downcase.pluralize
                else
                  @abstract_model.pretty_name.downcase.pluralize
                end
              scope = list_entries(@abstract_model.config, :destroy)
              @total = scope.size
              if params[:delete]
                if (model.singleton_method(:before_destroy) rescue nil)
                  scope.each(&:destroy)
                else
                  scope.delete_all
                end
                flash[:success] = "#{@total} #{@abstract_model.pretty_name.downcase.pluralize} successfully deleted"
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