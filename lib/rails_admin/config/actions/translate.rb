module RailsAdmin
  module Config
    module Actions

      class Translate < RailsAdmin::Config::Actions::Base

        register_instance_option :visible? do
          if authorized?
            model = bindings[:abstract_model].model rescue nil
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

            @model_config = RailsAdmin::Config.model(Forms::Translation)
            @bulk_ids = params.delete(:bulk_ids)
            translator_type = @action.class.translator_type
            done = false

            if model = @abstract_model.model rescue nil
              data_type = model.data_type
              data_type_selector = data_type.is_a?(Setup::BuildInDataType) ? nil : data_type
              if data = params[@model_config.abstract_model.param_key]
                translator = Setup::Translator.where(id: data[:translator_id]).first
                if (@object = Forms::Translation.new(
                  translator_type: translator_type,
                  bulk_source: (@bulk_ids.nil? && model.count != 1) || (@bulk_ids && @bulk_ids.size != 1),
                  data_type: data_type_selector,
                  translator: translator)).valid?

                  begin
                    do_flash_process_result Setup::Translation.process(translator_id: translator.id,
                                                                       bulk_ids: @bulk_ids,
                                                                       data_type_id: data_type.id)
                    done = true
                  rescue Setup::TransformingObjectException => ex
                    do_flash(:error, "Error updating object with id=#{ex.object.id}", ex.object.errors.full_messages)
                  rescue Exception => ex
                    flash[:error] = ex.message
                  end
                end
              end
            end
            if done
              redirect_to back_or_index
            else
              @object ||= Forms::Translation.new(
                translator_type: translator_type,
                bulk_source: (@bulk_ids.nil? && (model.nil? || model.count != 1)) || (@bulk_ids && @bulk_ids.size != 1),
                data_type: data_type_selector,
                translator: translator)

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

          def disable_buttons?
            true
          end
        end
      end

    end
  end
end