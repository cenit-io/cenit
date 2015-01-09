module RailsAdmin
  module Config
    module Actions
      class DeleteAll < RailsAdmin::Config::Actions::Base

        register_instance_option :visible? do
          if authorized?
            model = bindings[:abstract_model].model_name.constantize rescue nil
            model && model.all.size > 0
          else
            false
          end
        end

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do

            if model = @abstract_model.model_name.constantize rescue nil
              @total = model.all.size
              if params[:delete]
                model.delete_all
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