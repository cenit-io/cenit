module RailsAdmin
  module Config
    module Actions
      class Trash < RailsAdmin::Config::Actions::Base

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
                not_destroyed = []
                Setup::Collection.reflect_on_all_associations(:has_and_belongs_to_many).each do |relation|
                  @object.send(relation.name).each do |record|
                    unless record.destroy
                      not_destroyed += record.errors.full_messages
                    end
                  end
                end
                if not_destroyed.present?
                  do_flash(:warning, 'Some objects where not destroyed:', not_destroyed)
                else
                  flash[:success] = t('admin.flash.successful', name: @model_config.label, action: t('admin.actions.delete.done'))
                end
                redirect_path = index_path
              else
                flash[:error] = t('admin.flash.error', name: @model_config.label, action: t('admin.actions.delete.done'))
                redirect_path = back_or_index
              end
              redirect_to redirect_path
            else
              @collection = @object
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
