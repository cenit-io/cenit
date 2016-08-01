module RailsAdmin
  module Config
    module Actions

      class BulkPull < RailsAdmin::Config::Actions::Base

        register_instance_option :pjax? do
          true
        end

        register_instance_option :only do
          Setup::SharedCollection
        end

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do

            options_config = RailsAdmin::Config.model(Forms::PullOptions)
            @options_key = options_config.abstract_model.param_key
            if (@options = params[@options_key])
              @options.each { |k, v| @options[k] = v.to_b }
              @bulk_ids = params.delete(:new_bulk_ids) || params.delete(:bulk_ids) || Setup::SharedCollection.all.collect(&:id).collect(&:to_s)
              if (@object_id = params.delete(:object_id))
                @bulk_ids.delete(@object_id)
              else
                @object_id = @bulk_ids.pop
              end
              @object = Setup::SharedCollection.where(id: @object_id).first
              @pull_request = Cenit::Actions.pull_request(@object, pull_parameters: params[:pull_parameters], auto_fill: @options[:auto_fill])
              if @pull_request[:missing_parameters].blank? &&
                (params[:_pull] || (updated = @pull_request[:updated_records]).blank? || !@options[:pause_on_update] || (updated.size == 1 && updated.has_key?('namespaces')))
                @pull_request = Cenit::Actions.pull(@object, @pull_request) if @pull_request[:collection_data].present?
                done = @bulk_ids.blank?
                if (errors = @pull_request[:errors]).present?
                  if @options[:halt_on_error]
                    errors.unshift("Error pulling shared collection #{@object.versioned_name}")
                    do_flash(:error, t('admin.flash.error', name: @model_config.label, action: t("admin.actions.#{@action.key}.done").html_safe), errors)
                    redirect_to rails_admin.index_path(model_name: Setup::SharedCollection.to_s.underscore.gsub('/', '~'))
                    done = true
                  else
                    Setup::Notification.create_with(message: "Error pulling shared collection #{@object.versioned_name}",
                                                    attachment: {
                                                      filename: 'errors.txt',
                                                      contentType: 'plain/text',
                                                      body: errors.to_sentence
                                                    })
                  end
                end
                if done
                  redirect_to rails_admin.index_path(model_name: Setup::SharedCollection.to_s.underscore.gsub('/', '~')) unless errors.present?
                elsif @bulk_ids.present?
                  redirect_to rails_admin.bulk_pull_path(model_name: Setup::SharedCollection.to_s.underscore.gsub('/', '~'),
                                                         bulk_ids: @bulk_ids,
                                                         @options_key => @options)
                else
                  redirect_to_on_success
                end
              else
                if params[:_pull]
                  flash[:error] = t('admin.actions.pull.missing_parameters') if @pull_request[:missing_parameters].present?
                else
                  @pull_request[:missing_parameters] = []
                end
                render :pull, locals: {
                  shared_collection: @object,
                  pull_request: @pull_request,
                  bulk_ids: @bulk_ids,
                  object_id: @object_id,
                  options: @options,
                  options_key: @options_key
                }
              end
            else
              @form_object = Forms::PullOptions.new
              @model_config = options_config
              @warning_message =
                if params[:bulk_ids].present?
                  t('admin.actions.bulk_pull.warn', pull_size: params[:bulk_ids].size)
                else
                  t('admin.actions.bulk_pull.warn_all')
                end
              render :form
            end
          end
        end

        register_instance_option :link_icon do
          'icon-arrow-down'
        end

        register_instance_option :bulkable? do
          true
        end
      end

    end
  end
end