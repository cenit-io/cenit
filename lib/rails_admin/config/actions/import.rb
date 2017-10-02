module RailsAdmin
  module Config
    module Actions
      class Import < RailsAdmin::Config::Actions::Base

        register_instance_option :except do
          [Setup::Schema, Setup::ApiSpec]
        end

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
          [:get, :post, :patch]
        end

        register_instance_option :controller do
          proc do

            Forms::ImportTranslatorSelector.collection.drop
            selector_config = RailsAdmin::Config.model(Forms::ImportTranslatorSelector)
            render_form = true
            model = @abstract_model.model rescue nil
            if model
              data_type_selector = model.data_type
              if (data = params[selector_config.abstract_model.param_key])
                translator = Setup::Translator.where(id: data[:translator_id]).first
                decompress = data[:decompress_content].to_b
                if (@form_object = Forms::ImportTranslatorSelector.new(translator: translator,
                                                                       data_type: data_type_selector,
                                                                       options: data[:options],
                                                                       file: (file = data[:file]),
                                                                       data: (data = data[:data]))).valid?
                  begin
                    msg =
                      {
                        translator_id: translator.id,
                        data_type_id: model.data_type.id,
                        decompress_content: decompress,
                        data: if file.present?
                                file
                              elsif data.present?
                                data
                              else
                                nil
                              end,
                        options: @form_object.options
                      }
                    do_flash_process_result Setup::DataImport.process(msg) if msg[:data]
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
              @form_object ||= Forms::ImportTranslatorSelector.new(data_type: data_type_selector)
              @model_config = selector_config
              if @form_object.errors.present?
                do_flash(:error, 'There are errors in the import data specification', @form_object.errors.full_messages)
              end
              @form_object.save(validate: false)
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