module RailsAdmin
  module Models
    module Setup
      module WebHookNotificationAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Workflows'
            navigation_icon 'fa fa-anchor'
            object_label_method { :custom_title }
            label 'Web-Hook'

            configure :namespace, :enum_edit
            configure :data_type, :contextual_belongs_to
            configure :active, :toggle_boolean

            edit do
              field :namespace
              field :name

              field :data_type do
                required true
                inline_edit false
              end

              field :active do
                visible { !bindings[:object].data_type.nil? }
              end

              field :observers do
                required true
                label 'Events'
                visible { !bindings[:object].data_type.nil? }
                contextual_params do
                  if (dt = bindings[:object].data_type)
                    { data_type_id: dt.id.to_s }
                  end
                end
              end

              field :url, :string do
                required true
                visible { !bindings[:object].data_type.nil? }
              end

              field :http_method do
                required true
                visible { !bindings[:object].data_type.nil? }
              end

              field :transformation do
                required true
                label 'Template'
                visible { !bindings[:object].data_type.nil? }
                contextual_association_scope do
                  types = bindings[:object].class.transformation_types.collect(&:to_s)
                  proc do |scope|
                    scope.where(:_type.in => types)
                  end
                end
                contextual_params do
                  h = {}
                  if (dt = bindings[:object].data_type)
                    h[:source_data_type_id] = [nil, dt.id.to_s]
                  end
                  h
                end
                types do
                  bindings[:object].class.transformation_types
                end
              end

              field :template_options do
                visible { !bindings[:object].data_type.nil? }
              end
            end

            fields :name, :active, :data_type, :observers, :http_method, :url, :updated_at
          end
        end

      end
    end
  end
end
