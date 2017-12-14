module RailsAdmin
  module Models
    module Setup
      module XsltValidatorAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            weight 102
            parent ::Setup::Validator
            navigation_label 'Definitions'
            navigation_icon 'fa fa-check-square-o'
            label 'XSLT Validator'
            object_label_method { :custom_title }

            configure :code, :code do
              code_config do
                {
                  mode: 'application/xml'
                }
              end
            end

            list do
              field :namespace
              field :name
              field :updated_at
            end

            edit do
              field :namespace, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :name, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :code
            end

            fields :namespace, :name, :code, :updated_at
          end
        end

      end
    end
  end
end
