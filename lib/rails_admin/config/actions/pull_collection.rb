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

            @pull_request = Cenit::Actions.pull_request(@object, pull_parameters: params[:pull_parameters])
            if @pull_request[:missing_parameters].blank? && params[:_pull]
              @pull_request = Cenit::Actions.pull(@object, @pull_request)
              if (errors = @pull_request[:errors]).blank?
                redirect_to_on_success
              else
                flash[:error] = t('admin.flash.error', name: @model_config.label, action: t("admin.actions.#{@action.key}.done").html_safe).html_safe
                flash[:error] += %(<br>- #{errors[0..4].join('<br>- ')}).html_safe
                if errors.length - 5 > 0
                  flash[:error] += "<br>- and other #{errors.length - 5} errors.".html_safe
                end
                redirect_to back_or_index
              end
            else
              if params[:_pull]
                flash[:error] = 'Missing parameters' if  @pull_request[:missing_parameters].present?
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