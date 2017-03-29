module RailsAdmin
  module Models
    module Setup
      module WorkflowAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Workflows'
            object_label_method { :name }
            label 'Complex Flows'
            weight 500

            edit do
              field :name do
                read_only { bindings[:object].is_read_only? }
                required true
              end
              field :data_type do
                inline_edit false
                read_only { bindings[:object].is_read_only? }
                visible do
                  w = bindings[:object]
                  w.new_record? || !w.is_read_only? || !w.data_type.nil?
                end
              end
              field :description do
                read_only { bindings[:object].is_read_only? }
                required true
              end
              field :valid_from do
                read_only { bindings[:object].is_read_only? }
                required true
              end
              field :valid_to do
                read_only { bindings[:object].is_read_only? }
                required true
              end
              field :execution_mode, :enum do
                read_only { bindings[:object].is_read_only? }
                required true
              end
              field :status, :enum do
                required true
                visible { !bindings[:object].new_record? }
              end
              field :activities do
                required true
                visible { !bindings[:object].new_record? && !bindings[:object].is_read_only? }
              end
              field :diagram do
                read_only true
                visible { !bindings[:object].new_record? }
                formatted_value { bindings[:object].to_svg.html_safe }
              end
            end

            list do
              field :name
              field :valid_from
              field :valid_to
              field :updated_at
              field :status
            end

            show do
              field :name
              field :valid_from
              field :valid_to
              field :updated_at
              field :status
              field :diagram do
                formatted_value { bindings[:object].to_svg.html_safe }
              end
            end

          end
        end

      end
    end
  end
end
