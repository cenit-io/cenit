module RailsAdmin
  module Models
    module TaskTokenAdmin
      extend ActiveSupport::Concern

      included do
        rails_admin do
          weight 890
          navigation_label 'Administration'
          parent ::Cenit::BasicToken
          visible { ::User.current_super_admin? }
        end
      end
    end
  end
end
