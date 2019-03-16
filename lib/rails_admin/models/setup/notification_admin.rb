module RailsAdmin
  module Models
    module Setup
      module NotificationAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            object_label_method { :custom_title }
            navigation_label 'Workflows'
            navigation_icon 'fa fa-bullhorn'
            label 'Notification'
            weight 500

            configure :data_type, :contextual_belongs_to
            configure :active, :toggle_boolean

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
                inline_add false
                visible { !bindings[:object].data_type.nil? }
                associated_collection_scope do
                  limit = (associated_collection_cache_all ? nil : 30)
                  data_type = bindings[:object].data_type || bindings[:controller].object
                  proc { |scope| scope.where(data_type_id: data_type.id).limit(limit) }
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
            end

            fields :namespace, :name, :active, :data_type, :observers, :updated_at
          end
        end
      end
    end
  end
end
