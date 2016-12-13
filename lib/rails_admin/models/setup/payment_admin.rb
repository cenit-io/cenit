module RailsAdmin
  module Models
    module Setup
      module PaymentAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            weight 851
            navigation_label 'Administration'
            visible { User.current_super_admin? }

            edit do
              field :_id do
                read_only { !bindings[:object].new_record? }
              end
              field :title
              field :description
              field :date
              field :mount
              field :credit
            end

            fields :_id, :title, :description,  :date, :mount, :credit
          end
        end

      end
    end
  end
end
