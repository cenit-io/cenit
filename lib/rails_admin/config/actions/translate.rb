module RailsAdmin
  module Config
    module Actions

      class Translate < RailsAdmin::Config::Actions::Base

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

            @bulk_ids = params.delete(:bulk_ids)
            translator_type = @action.class.translator_type

            if model = @abstract_model.model_name.constantize rescue nil
              data_type = model.data_type
              data_type_selector = data_type.is_a?(Setup::BuildInDataType) ? nil : data_type
              if data = params[:forms_translator_selector]
                translator = Setup::Translator.where(id: data[:translator_id]).first
                if (@object = Forms::TranslatorSelector.new(
                  translator_type: translator_type,
                  bulk_source: (@bulk_ids.nil? && model.count != 1) || (@bulk_ids && @bulk_ids.size != 1),
                  data_type: data_type_selector,
                  translator: translator)).valid?

                  begin
                    translation = @action.class.translate(translator: translator,
                                                          bulk_ids: @bulk_ids,
                                                          model: model,
                                                          data_type: data_type)
                    ok = true
                  rescue Setup::TransformingObjectException => ex
                    do_flash(:error, "Error updating object with id=#{ex.object.id}", ex.object.errors.full_messages)
                  rescue Exception => ex
                    raise ex
                    flash[:error] = ex.message
                  end
                end
              end
            end
            if ok
              @action.class.done(controller: self,
                                 translation: translation,
                                 back_or_index: back_or_index,
                                 data_type: data_type,
                                 translator: translator)
            else
              @object ||= Forms::TranslatorSelector.new(
                translator_type: translator_type,
                bulk_source: (@bulk_ids.nil? && (model.nil? || model.count != 1)) || (@bulk_ids && @bulk_ids.size != 1),
                data_type: data_type_selector,
                translator: translator)
              @model_config = RailsAdmin::Config.model(Forms::TranslatorSelector)
              if @object.errors.present?
                do_flash_now(:error, 'There are errors in the export data specification', @object.errors.full_messages)
              end
              render :translate
            end

          end
        end

        register_instance_option :bulkable? do
          true
        end

        class << self

          def translator_type
            nil
          end

          def translate(options)
            nil
          end

          def done(options)
            options[:controller].redirect_to options[:back_or_index]
          end

          def disable_buttons?
            true
          end
        end
      end

    end
  end
end