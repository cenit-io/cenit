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
            errors = []
            begin
              collection = Setup::Collection.new
              collection.from_json(@object.data)
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
          end
        end

        register_instance_option :link_icon do
          'icon-arrow-down'
        end
      end

    end
  end
end