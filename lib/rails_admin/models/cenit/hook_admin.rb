module RailsAdmin
  module Models
    module Cenit
      module HookAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Workflows'
            navigation_icon 'fa fa-archive'
            weight 515

            edit do
              field :namespace, :enum_edit
              field :name
              field :channels
            end

            fields :namespace, :name, :channels, :token, :created_at
          end
        end
      end
    end
  end
end
