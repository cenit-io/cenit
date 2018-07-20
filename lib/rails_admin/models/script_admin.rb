module RailsAdmin
  module Models
    module ScriptAdmin
      extend ActiveSupport::Concern

      included do
        rails_admin do
          weight 830
          navigation_label 'Administration'
          visible { ::User.current_super_admin? }

          configure :code, :code do
            code_config do
              {
                mode: 'text/x-ruby'
              }
            end
          end

          edit do
            field :name
            field :description
            field :code
          end

          show do
            field :name
            field :description
            field :code
          end

          list do
            field :name
            field :description
            field :code
            field :updated_at
          end

          fields :name, :description, :code, :updated_at
        end
      end
    end
  end
end
