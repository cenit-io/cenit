module RailsAdmin
  module Config
    module Actions

      class EdiExport < RailsAdmin::Config::Actions::Base

        register_instance_option :visible? do
          if authorized?
            model = bindings[:abstract_model].model_name.constantize rescue nil
            model.respond_to?(:data_type_id)
          else
            false
          end
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do

            object = @object
            @object = nil

            if data = params[:forms_export_translator_selector]
              translator = Setup::Translator.where(id: data[:translator_id]).first
              if (@object = Forms::ExportTranslatorSelector.new(translator: translator)).valid?
                begin
                  render plain: translator.run(object: object)
                  ok = true
                rescue Exception => ex
                  #raise ex
                  flash[:error] = ex.message
                end
              end
            end
            unless ok
              @object ||= Forms::ExportTranslatorSelector.new
              @model_config = RailsAdmin::Config.model(Forms::ExportTranslatorSelector)
              unless @object.errors.blank?
                flash.now[:error] = 'There are errors in the export data specification'.html_safe
                flash.now[:error] += %(<br>- #{@object.errors.full_messages.join('<br>- ')}).html_safe
              end
            end

          end
        end

        register_instance_option :link_icon do
          'icon-download'
        end

      end

    end
  end
end