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

            ffields = []

            ::Setup::Binding.reflect_on_all_associations(:belongs_to).each do |relation|
              ffields << relation.name
              if relation.name.to_s.ends_with?('binder')
                configure relation.name, :belongs_to_association do
                  label { "Binder #{RailsAdmin.config(relation.klass).label}" }
                end
              else
                configure relation.name, :belongs_to_association do
                  label { "#{RailsAdmin.config(relation.klass).label} Bind" }
                end
              end
            end

            edit do
              ::Setup::Binding.reflect_on_all_associations(:belongs_to).each do |relation|
                if relation.name.to_s.ends_with?('binder')
                  field relation.name do
                    label { RailsAdmin.config(relation.klass).label }
                    read_only true
                    visible { value.present? }
                    help ''
                  end
                else
                  field relation.name do
                    label { RailsAdmin.config(relation.klass).label }
                    inline_edit false
                    inline_add false
                    visible { value.present? }
                    help ''
                  end
                end
              end
            end

            list do
              field :binder_model
              field :binder
              field :bind_model
              field :bind
              field :updated_at
            end

            ffields << :updated_at

            filter_fields *ffields

            show_in_dashboard false
          end
        end
      end
    end
  end
end
