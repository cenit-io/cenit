module RailsAdmin
  module Config
    module Actions
      class Import < RailsAdmin::Config::Actions::Base

        register_instance_option :except do
          Setup::Schema
        end

        register_instance_option :visible? do
          if authorized?
            model = bindings[:abstract_model].model rescue nil
            model.try(:data_type)
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

            selector_config = RailsAdmin::Config.model(Forms::ImportTranslator)
            render_form = true
            model = @abstract_model.model rescue nil
            if model
              data_type_selector = model.data_type
              data_type_selector = nil if data_type_selector.is_a?(Setup::BuildInDataType)
              if (data = params[selector_config.abstract_model.param_key])
                translator = Setup::Translator.where(id: data[:translator_id]).first
                if (@form_object = Forms::ImportTranslator.new(translator: translator, data_type: data_type_selector, file: (file = data[:file]), data: (data = data[:data]))).valid?
                  begin
                    do_flash_process_result Setup::DataImport.process(translator_id: translator.id, data_type_id: model.data_type.id, data: file.read) if file
                    do_flash_process_result Setup::DataImport.process(translator_id: translator.id, data_type_id: model.data_type.id, data: data) if data
                    render_form = false
                  rescue Exception => ex
                    flash[:error] = ex.message
                  end
                end
              end
            else
              flash[:error] = 'Error loading model'
            end
            if render_form
              @form_object ||= Forms::ImportTranslator.new(data_type: data_type_selector)
              @model_config = selector_config
              if @form_object.errors.present?
                do_flash(:error, 'There are errors in the import data specification', @form_object.errors.full_messages)
              end

              render :form
            else
              redirect_to back_or_index
            end

          end
        end

        register_instance_option :link_icon do
          'icon-upload'
        end
      end
    end
  end
end