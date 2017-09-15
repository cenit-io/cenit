module RailsAdmin
  module Models
    module Setup
      module BindingAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Configuration'
            weight 750
            visible true
            object_label_method { :label }

            configure :binder_model, :model
            configure :binder, :record
            configure :bind_model, :model
            configure :bind, :record

            edit do
              ::Setup::Binding.reflect_on_all_associations(:belongs_to).each do |relation|
                if relation.name.to_s.ends_with?('binder')
                  field relation.name do
                    label { relation.klass.to_s.split('::').last.to_title }
                    read_only true
                    visible { value.present? }
                    help ''
                  end
                else
                  field relation.name do
                    label { relation.klass.to_s.split('::').last.to_title }
                    inline_edit false
                    inline_add false
                    visible { value.present? }
                    help ''
                  end
                end
              end
            end

            fields :binder_model, :binder, :bind_model, :bind, :updated_at

            show_in_dashboard false
          end
        end

      end
    end
  end
end
