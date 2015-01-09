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

            if file_content = params[:file_content]
              model = @abstract_model.model_name.constantize rescue nil
              begin
                flash[:error]=''
                begin
                  report = EDI::Parser.parse(model.data_type, file_content = file_content.gsub("\r", ''))
                  flash.delete(:error)
                rescue Exception => ex
                  flash[:error] +=ex.message
                end
                unless report
                  report = EDI::Parser.parse(model.data_type, file_content, 0, :by_fixed_length)
                  ok = true
                  if (@object = report[:record]).valid?(:create) && Import.save(@object)
                    flash.delete(:error)
                    redirect_to_on_success
                  else
                    handle_save_error
                  end
                end
              rescue Exception => ex
                flash[:error] += ex.message
              end
              redirect_to back_or_index unless ok
            else
              render @action.template_name
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