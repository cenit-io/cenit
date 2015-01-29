module RailsAdmin
  module Config
    module Actions
      class Import < RailsAdmin::Config::Actions::Base

        register_instance_option :visible? do
          if authorized?
            model = bindings[:abstract_model].model_name.constantize rescue nil
            model.respond_to?(:data_type) && model.data_type
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
                if (@object = form_object = Forms::ImportTranslatorSelector.new(translator: translator, data: data[:data])).valid?
                  begin
                    @object = translator.run(target_data_type: model.data_type, data: data[:data])
                    if @object.is_a?(model)
                      if @object.valid?(:create) && Import.save(@object)
                        redirect_to_on_success
                      else
                        handle_save_error
                      end
                      render_form = false
                    else
                      form_object.errors.add(:translator, "Translation result of type #{model.title} expected but #{@object.class} found")
                    end
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
              unless @object.errors.blank?
                flash.now[:error] = 'There are errors in the import data specification'.html_safe
                flash.now[:error] += %(<br>- #{@object.errors.full_messages.join('<br>- ')}).html_safe
              end
            end

          end
        end

        register_instance_option :link_icon do
          'icon-upload'
        end

        private

        def self.save(record)
          save_references(record) && record.save(validate: false)
        end

        def self.save_references(record)
          record.reflect_on_all_associations(:embeds_one,
                                             :embeds_many,
                                             :has_one,
                                             :has_many,
                                             :has_and_belongs_to_many).each do |relation|
            if values = record.send(relation.name)
              values = [values] unless values.is_a?(Enumerable)
              values.each { |value| return false unless save_references(value) }
              values.each { |value| return false unless value.save(validate: false) } unless relation.embedded?
            end
          end
          return true
        end

        def self.tail_attributes(json)
          if json.is_a?(Array)
            json_att = []
            json.each do |value|
              json_att << tail_attributes(value)
            end
          elsif json.is_a?(Hash)
            json_att = {}
            json.each do |property, value|
              property = "#{property}_attributes" if value.is_a?(Hash) || value.is_a?(Array)
              json_att[property] = tail_attributes(value)
            end
          else
            json_att = json
          end
          return json_att
        end
      end
    end
  end
end