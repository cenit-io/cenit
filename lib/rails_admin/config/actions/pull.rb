module RailsAdmin
  module Config
    module Actions

      class Pull < RailsAdmin::Config::Actions::Base

        register_instance_option :pjax? do
          true
        end

        register_instance_option :only do
          [Setup::SharedCollection, Setup::CrossSharedCollection]
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do

            @pull_request = Cenit::Actions.pull_request(@object, pull_parameters: params[:pull_parameters])
            if @pull_request[:missing_parameters].blank? && params[:_pull]
              @pull_request = Cenit::Actions.pull(@object, @pull_request) if @pull_request[:collection_data].present?
              if (errors = @pull_request[:errors]).blank?
                if (errors = @pull_request[:fixed_errors])
                  do_flash(:notice, t('admin.actions.pull_collection.fixed_errors_header'), errors)
                end
                collection = Setup::Collection.where(name: @object.name).first
                if collection
                  flash[:success] = t('admin.flash.successful', name: @model_config.label, action: t("admin.actions.#{@action.key}.done"))
                  redirect_to rails_admin.show_path(model_name: collection.class.to_s.underscore.gsub('/', '~'), id: collection.id)
                else
                  redirect_to_on_success
                end
              else
                do_flash(:error, t('admin.flash.error', name: @model_config.label, action: t("admin.actions.#{@action.key}.done").html_safe), errors)
                redirect_to back_or_index
              end
            else
              if params[:_pull]
                flash[:error] = t('admin.actions.pull_collection.missing_parameters') if @pull_request[:missing_parameters].present?
              else
                @pull_request[:missing_parameters] = []
              end
              render @action.template_name
            end
          end
        end

        register_instance_option :link_icon do
          'icon-arrow-down'
        end
      end

    end
  end
end