module RailsAdmin
  module Models
    module Setup
      module CategoryAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            weight 850
            navigation_label 'Administration'
            visible { ::User.current_super_admin? }

            edit do
              field :_id do
                read_only { !bindings[:object].new_record? }
              end
              field :title
              field :description
            end

            fields :_id, :title, :description, :updated_at
          end
        end
      end
    end
  end
end
