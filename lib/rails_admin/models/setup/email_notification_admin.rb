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

            visible { User.current_super_admin? }

            configure :data_type, :contextual_belongs_to

            edit do
              field :namespace
              field :name
              field :active

              field :data_type do
                inline_edit false
              end

              field :observers do
                label 'Events'
                visible { !bindings[:object].data_type.nil? }
                contextual_params do
                  if (dt = bindings[:object].data_type)
                    { data_type_id: dt.id.to_s }
                  end
                end
              end

              field :transformation do
                label 'Template'
                visible { !bindings[:object].data_type.nil? }
                contextual_association_scope do
                  types = bindings[:object].class.transformation_types.collect(&:to_s)
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
              end

              field :email_channel do
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
