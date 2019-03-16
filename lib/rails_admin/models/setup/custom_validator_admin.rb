module RailsAdmin
  module Models
    module Setup
      module CustomValidatorAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            visible false

            configure :_type do
              pretty_value do
                value.split('::').last.to_title
              end
            end

            list do
              field :namespace
              field :name
              field :_type
              field :updated_at
            end

            fields :namespace, :name, :_type, :updated_at
          end
        end
      end
    end
  end
end
