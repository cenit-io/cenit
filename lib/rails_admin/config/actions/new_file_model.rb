module RailsAdmin
  module Config
    module Actions

      class NewFileModel < RailsAdmin::Config::Actions::Base

        register_instance_option :pjax? do
          false
        end

        register_instance_option :only do
          Setup::Model
        end

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do
            done = false
            file_model_config = RailsAdmin::Config.model(Setup::FileDataType)
            if params[:_restart].nil? && (shared_params = params[file_model_config.abstract_model.param_key])
              @file_model = Setup::FileDataType.new(shared_params.to_hash)
              done = @file_model.save if params[:_save]
            end
            if done
              redirect_to back_or_index
            else
              @file_model ||= Setup::FileDataType.new
              @file_model.instance_variable_set(:@_selecting_library, @file_model.library.blank?)
              @model_config = file_model_config
              if params[:_save] && @file_model.errors.present?
                flash.now[:error] = t('admin.flash.error', name: @model_config.label, action: t("admin.actions.#{@action.key}.done").html_safe).html_safe
                flash.now[:error] += %(<br>- #{@file_model.errors.full_messages.join('<br>- ')}).html_safe
              end
            end

          end
        end

        register_instance_option :link_icon do
          'icon-plus'
        end
      end

    end
  end
end