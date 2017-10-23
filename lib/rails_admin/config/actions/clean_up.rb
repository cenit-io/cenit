module RailsAdmin
  module Config
    module Actions

      class CleanUp < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Account
        end

        register_instance_option :pjax? do
          true
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get, :delete]
        end

        register_instance_option :controller do
          proc do
            if params[:delete] # DELETE
              @object.clean_up
              redirect_to back_or_index
            else
              @object = Setup::Collection.new
              Setup::Collection.reflect_on_all_associations(:has_and_belongs_to_many).each do |relation|
                @object.send("#{relation.name}=", relation.klass.where(origin: :default))
              end
              @warning_message = t('admin.actions.clean_up.warn')
              render :trash
            end
          end
        end

        register_instance_option :link_icon do
          'icon-trash'
        end

        def template_name
          :trash
        end
      end

    end
  end
end