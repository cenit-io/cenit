module RailsAdmin
  module Config
    module Actions
      class Translate < RailsAdmin::Config::Actions::Base

        register_instance_option :visible? do
          if authorized?
            begin
              bindings[:abstract_model].model.data_type.present?
            rescue
              false
            end
          else
            false
          end
        end

        register_instance_option :http_methods do
          [:get, :patch]
        end

        register_instance_option :controller do
          proc do
            Forms::TransformationSelector.collection.drop
            translation_config = RailsAdmin::Config.model(Forms::TransformationSelector)
            translator_type = @action.class.translator_type
            done = false
            model = process_bulk_scope
            bulk_source = (@bulk_ids.nil? && model.count != 1) || (@bulk_ids && @bulk_ids.size != 1)

            if model && (data_type = model.try(:data_type))
              if (data = params[translation_config.abstract_model.param_key])
                translator = Setup::Translator.where(id: data[:translator_id]).first
                if (@form_object = Forms::TransformationSelector.new(
                  translator_type: translator_type,
                  bulk_source: bulk_source,
                  data_type: data_type,
                  translator: translator,
                  options: data[:options])).valid?
                  begin
                    do_flash_process_result Setup::Translation.process(
                      translator_id: translator.id,
                      bulk_ids: @bulk_ids,
                      data_type_id: data_type.id,
                      skip_notification_level: true,
                      options: @form_object.options)
                    done = true
                  rescue Exception => ex
                    flash[:error] = ex.message
                  end
                end
              end
            end
            if done
              redirect_to back_or_index
            else
              @model_config = translation_config
              @form_object ||= Forms::TransformationSelector.new(
                translator_type: translator_type,
                bulk_source: bulk_source,
                data_type: data_type,
                translator: translator)
              if @form_object.errors.present?
                do_flash_now(:error, "There are errors in the #{@action.class.translator_type.to_s.downcase} data specification", @form_object.errors.full_messages)
              end
              @form_object.save(validate: false)
              render :form, locals: { bulk_alert: true }
            end
          end
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
