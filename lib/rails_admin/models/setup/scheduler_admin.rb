module RailsAdmin
  module Models
    module Setup
      module SchedulerAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Workflows'
            weight 512
            object_label_method { :custom_title }

            configure :namespace, :enum_edit

            configure :expression, :json_value

            edit do
              field :namespace
              field :name

              field :expression do
                visible true
                label 'Scheduling type'
                help 'Configure scheduler'
                partial :scheduler
                html_attributes do
                  { rows: '1' }
                end

              end
            end

            show do
              field :namespace
              field :name
              field :expression

              field :_id
              field :created_at
              #field :creator
              field :updated_at
              #field :updater
            end

            list do
              field :namespace
              field :name
              field :expression
              field :activated
              field :updated_at
            end

            fields :namespace, :name, :expression, :activated, :updated_at
          end
        end

      end
    end
  end
end
