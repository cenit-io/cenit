module RailsAdmin
  module Models
    module Setup
      module ForeignNotificationEmailAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            object_label_method { :name }
            label 'Email'
            weight 500

            edit do
              required_help = '<i class="fa fa-warning"></i> Required.'
              handlebars_help = '<i class="fa fa-question-circle"></i> You can use <a href="http://handlebarsjs.com/" target="_blank">handlebar</a> to form the value from the record data.'
              body_template_help = '<i class="fa fa-question-circle"></i> Set the empty value if you want to use a custom mail body.'

              field :name, :string do
                required true
              end

              field :active, :boolean do
                visible do
                  ctrl = bindings[:controller]
                  model_name = ctrl.instance_variable_get(:@model_name)
                  bindings[:object].data_type ||= ctrl.instance_variable_get(:@data_type_filter)
                  bindings[:object].data_type ||= ctrl.object if model_name == 'Setup::JsonDataType'
                  bindings[:object].data_type != nil
                end
              end

              field :data_type do
                required true
                inline_edit false
                read_only do
                  bindings[:object].data_type != nil
                end
                help do
                  text = ''
                  if bindings[:object].data_type.nil?
                    text << "<i class='fa fa-warning'></i> Required.<br/>"
                    text << "<i class='fa fa-warning'></i> To set observers, you must first use the save and edit action."
                  end
                  text.html_safe
                end
              end

              field :observers do
                label 'Events'
                inline_add false
                visible { !bindings[:object].data_type.nil? }
                associated_collection_scope do
                  data_type = bindings[:object].data_type || bindings[:controller].object
                  proc { |scope| scope.where(data_type_id: data_type.id) }
                end
                help do
                  text = 'Required.'
                  if bindings[:controller].instance_variable_get(:@model_name) == 'Setup::JsonDataType'
                    text = "<i class='fa fa-warning'></i> Required.<br/>"
                    text << "<i class='fa fa-warning'></i> To use a newly created observer in this session or set setting values, you must first use the save and edit action."
                  end
                  text.html_safe
                end
              end

              field :smtp_provider do
                label 'SMTP Setting'
                required true
                associated_collection_cache_all false
              end

              field :to, :string do
                required true
                help "#{required_help}<br/>#{handlebars_help}".html_safe
              end

              field :subject, :string do
                required true
                help "#{required_help}<br/>#{handlebars_help}".html_safe
              end

              field :body_template do
                associated_collection_cache_all false
                associated_collection_scope do
                  proc { |scope| scope.where(mime_type: { '$in' => ['text/html', 'text/plain'] }) }
                end
                help body_template_help.html_safe
              end

              field :body, :text do
                required true
                help "#{required_help}<br/>#{handlebars_help}".html_safe
              end

              field :attachment_template do
                associated_collection_cache_all false
                associated_collection_scope do
                  proc { |scope| scope.where(mime_type: { '$in' => ['application/pdf'] }) }
                end
              end

              field :scripts do
                formatted_value { bindings[:object] }
                partial 'foreign_notification/form_email_setting_scripts'
              end
            end

            fields :name, :active, :data_type, :observers, :updated_at
          end
        end

      end
    end
  end
end

