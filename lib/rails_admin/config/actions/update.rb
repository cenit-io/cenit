module RailsAdmin
  module Config
    module Actions

      class Update < RailsAdmin::Config::Actions::Base

        register_instance_option :except do
          [Setup::Library, Setup::Schema, Setup::DataType]
        end

        register_instance_option :visible? do
          if authorized?
            model = bindings[:abstract_model].model_name.constantize rescue nil
            model.try(:data_type).present?
          else
            false
          end
        end

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :controller do
          proc do

            @bulk_ids = params[:bulk_ids]
            if model = @abstract_model.model_name.constantize rescue nil
              if data = params[:forms_update_translator_selector]
                translator = Setup::Translator.where(id: data[:translator_id]).first
                if (@object = Forms::UpdateTranslatorSelector.new(translator: translator)).valid?
                  begin
                    (@bulk_ids ? list_entries(@model_config, :update) : model.all).each do |object|
                      translator.run(object: object)
                    end
                    ok = true
                  rescue Setup::TransformingObjectException => ex
                    flash.now[:error] = "Error updating object with id=#{ex.object.id}".html_safe
                    flash.now[:error] += %(<br>- #{ex.object.errors.full_messages.join('<br>- ')}).html_safe
                  rescue Exception => ex
                    #raise ex
                    flash[:error] = ex.message
                  end
                end
              end
            end
            if ok
              redirect_to back_or_index
            else
              @object ||= Forms::UpdateTranslatorSelector.new
              @model_config = RailsAdmin::Config.model(Forms::UpdateTranslatorSelector)
              unless @object.errors.blank?
                flash.now[:error] = 'There are errors in the export data specification'.html_safe
                flash.now[:error] += %(<br>- #{@object.errors.full_messages.join('<br>- ')}).html_safe
              end
              render @action.template_name
            end

          end
        end

        register_instance_option :bulkable? do
          true
        end

        register_instance_option :link_icon do
          'icon-edit'
        end

      end

    end
  end
end