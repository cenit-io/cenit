module RailsAdmin
  module Config
    module Actions
      class Import < RailsAdmin::Config::Actions::Base

        register_instance_option :except do
          [Setup::Schema, Setup::Model]
        end

        register_instance_option :visible? do
          if authorized?
            model = bindings[:abstract_model].model_name.constantize rescue nil
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

            render_form = true
            form_object = nil
            if model = @abstract_model.model_name.constantize rescue nil
              if data = params[:forms_import_translator_selector]
                translator = Setup::Translator.where(id: data[:translator_id]).first
                if (form_object = Forms::ImportTranslatorSelector.new(translator: translator, data: data[:data])).valid?
                  begin
                    translator.run(target_data_type: model.data_type, data: data[:data])
                    redirect_to_on_success
                    render_form = false
                  rescue Setup::TransformingObjectException => ex
                    @object = ex.object
                    handle_save_error
                  rescue Exception => ex
                    raise ex
                    form_object.errors.add(:data, ex.message)
                  end
                end
              end
            else
              flash[:error] = 'Error loading model'
            end
            if render_form
              @object = form_object || Forms::ImportTranslatorSelector.new
              @model_config = RailsAdmin::Config.model(Forms::ImportTranslatorSelector)
              if @object.errors.present?
                flash.now[:error] = 'There are errors in the import data specification'.html_safe
                flash.now[:error] += %(<br>- #{@object.errors.full_messages.join('<br>- ')}).html_safe
              end
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