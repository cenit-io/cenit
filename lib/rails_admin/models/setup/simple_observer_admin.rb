module RailsAdmin
  module Models
    module Setup
      module SimpleObserverAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            object_label_method { :custom_title }
            label 'Observer'
            weight 511

            edit do
              field :name
              field :triggers do
                visible do
                  ctrl = bindings[:controller]
                  ctrl.instance_variable_set(:@_data_type, ctrl.instance_variable_get(:@object))
                end
                partial 'form_triggers'
              end
            end
          end
        end

      end
    end
  end
end
