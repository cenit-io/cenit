module RailsAdmin
  module Config
    module Actions
      class DeleteCollection < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::Collection
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
              if @auditing_adapter
                collection_abstract_model = RailsAdmin::Config.model(Setup::Collection).abstract_model
                @auditing_adapter.delete_object(@object, @abstract_model, _current_user)
              end
              if @object.destroy
                Setup::Collection.reflect_on_all_associations(:has_and_belongs_to_many).each do |relation|
                  @object.send(relation.name).each { |record| record.destroy } #TODO Report not destroyed records
                end
                flash[:success] = t('admin.flash.successful', name: @model_config.label, action: t('admin.actions.delete.done'))
                redirect_path = index_path
              else
                flash[:error] = t('admin.flash.error', name: @model_config.label, action: t('admin.actions.delete.done'))
                redirect_path = back_or_index
              end
              redirect_to redirect_path
            else
              render 'delete_collection'
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
