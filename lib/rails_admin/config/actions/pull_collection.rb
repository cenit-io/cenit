module RailsAdmin
  module Config
    module Actions

      class PullCollection < RailsAdmin::Config::Actions::Base

        register_instance_option :pjax? do
          false
        end

        register_instance_option :only do
          Setup::SharedCollection
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do

            @parameter_values = (params[:pull_parameters] && params[:pull_parameters].to_hash) || {}
            @missing_parameters = []
            @object.pull_parameters.each { |pull_parameter| @missing_parameters << pull_parameter.parameter unless @parameter_values[pull_parameter.parameter].present? }
            errors = []
            if @missing_parameters.blank?
              begin
                collection = Setup::Collection.new
                collection.from_json(@object.data_with(@parameter_values))
                collection.errors.full_messages.each { |msg| errors << msg } unless Setup::Translator.save(collection)
              rescue Exception => ex
                errors << ex.message
              end
              if errors.blank?
                redirect_to_on_success
              else
                flash[:error] = t('admin.flash.error', name: @model_config.label, action: t("admin.actions.#{@action.key}.done").html_safe).html_safe
                flash[:error] += %(<br>- #{errors.join('<br>- ')}).html_safe
                redirect_to back_or_index
              end
            else
              if params[:_pull]
                flash[:error] = 'Missing parameters' if @missing_parameters.present?
              else
                @missing_parameters = []
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