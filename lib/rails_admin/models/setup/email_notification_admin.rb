module RailsAdmin
  module Models
    module Setup
      module EmailNotificationAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            object_label_method { :custom_title }
            navigation_label 'Workflows'
            navigation_icon 'fa fa-envelope-o'
            label 'Email'
            weight 500

            configure :namespace, :enum_edit
            configure :data_type, :contextual_belongs_to
            configure :active, :toggle_boolean

            edit do
              field :namespace
              field :name
              field :active

              field :data_type do
                required true
                inline_edit false
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

              field :transformation do
                required true
                label 'Template'
                visible { !bindings[:object].data_type.nil? }
                contextual_association_scope do
                  types = bindings[:object].class.transformation_types.collect(&:concrete_class_hierarchy).flatten.uniq
                  proc do |scope|
                    scope.where(:_type.in => types)
                  end
                end
                contextual_params do
                  h = { target_data_type_id: ::Setup::EmailNotification.email_data_type_id }
                  if (dt = bindings[:object].data_type)
                    h[:source_data_type_id] = [nil, dt.id.to_s]
                  end
                  h
                end
                types do
                  bindings[:object].class.transformation_types.collect(&:concrete_class_hierarchy).flatten.uniq
                end
              end

              field :email_channel do
                required true
                visible { !bindings[:object].data_type.nil? }
              end
            end

            fields :namespace, :name, :active, :data_type, :observers, :email_channel, :updated_at
          end
        end

      end
    end
  end
end
