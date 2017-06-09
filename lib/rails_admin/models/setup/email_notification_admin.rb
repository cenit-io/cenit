module RailsAdmin
  module Models
    module Setup
      module EmailNotificationAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            object_label_method { :name }
            label 'Email'
            visible { User.current_super_admin? }
            weight 500

            configure :data_type, :contextual_belongs_to

            edit do
              field :namespace
              field :name

              field :active do
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
                visible { !bindings[:object].data_type.nil? }
                help do
                  text = 'Required.'
                  if bindings[:controller].instance_variable_get(:@model_name) != 'Setup::ForeignNotificationEmail'
                    text = "<i class='fa fa-warning'></i> Required.<br/>"
                    text << "<i class='fa fa-warning'></i> To use a newly created observer in this session or set setting values, you must first use the save and edit action."
                  end
                  text.html_safe
                end
                contextual_params do
                  if (dt = bindings[:object].data_type)
                    { data_type_id: dt.id.to_s }
                  end
                end
              end

              field :transformation do
                label 'Template'
                required true
                visible { !bindings[:object].data_type.nil? }
                contextual_association_scope do
                  types = bindings[:object].class.transformation_types.collect(&:to_s)
                  proc do |scope|
                    scope.where(:_type.in => types)
                  end
                end
                contextual_params do
                  h = { target_data_type_id: (dt = ::Cenit.namespace('MIME').data_type('Message')) && dt.id.to_s }
                  if (dt = bindings[:object].data_type)
                    h[:source_data_type_id] = [nil, dt.id.to_s]
                  end
                  h
                end
              end

            end

            fields :namespace, :name, :active, :data_type, :observers, :updated_at
          end
        end

      end
    end
  end
end
