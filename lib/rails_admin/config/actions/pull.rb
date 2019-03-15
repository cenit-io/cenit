module RailsAdmin
  module Config
    module Actions

      class Pull < RailsAdmin::Config::Actions::Base

        register_instance_option :pjax? do
          true
        end

        register_instance_option :only do
          [Setup::CrossSharedCollection, Setup::ApiSpec]
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get, :post, :patch]
        end

        register_instance_option :controller do
          proc do
            if (pull_parameters = params[:pull_parameters])
              pull_parameters.permit!
              RailsAdmin::Config.model(@object.pull_model).edit.fields.each { |field| field.parse_input(pull_parameters) }
            end

            if @object.pull_asynchronous
              if params[:_pull]
                message = {
                  skip_pull_review: params[:skip_pull_review].to_b
                }
                if @object.try(:pull_parameters?)
                  message[:pull_parameters] = @object.pull_model.new(pull_parameters || {}).share_hash
                end
                do_flash_process_result object.pull(message)
                redirect_to back_or_index
              else
                render :pull, locals: {
                  shared_collection: @object.is_a?(Setup::CrossSharedCollection) ? @object : nil,
                  pull_review_option: true
                }
              end
            else
              pull_parameters = @object.pull_model.new(pull_parameters || {}).share_hash
              @pull_request = Cenit::Actions.pull_request(@object, pull_parameters: pull_parameters)
              if @pull_request[:missing_parameters].blank? && params[:_pull]
                @pull_request[:install] = params[:install].to_b if ::User.current_super_admin? && ::User.current_installer?
                @pull_request = Cenit::Actions.pull(@object, @pull_request) if (!@object.installed? && @pull_request[:install]) || @pull_request[:collection_data].present?
                if (errors = @pull_request[:errors]).blank?
                  if (errors = @pull_request[:fixed_errors])
                    do_flash(:notice, t('admin.actions.pull.fixed_errors_header'), errors)
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
                locals =
                  {
                    shared_collection: @object,
                    pull_request: @pull_request,
                    bulk_ids: @bulk_ids,
                    object_id: @object_id,
                    options: @options,
                    options_key: @options_key
                  }
                if ::User.current_super_admin? && !@object.installed?
                  locals[:before_form_partials] = :install_option
                  locals[:pull_anyway] = ::User.current_installer?
                end
                render :pull, locals: locals
              end
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