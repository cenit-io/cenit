module RailsAdmin
  module Models
    module Setup
      module AwsAuthorizationAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            weight -334
            object_label_method { :custom_title }

            configure :metadata, :json_value

            child_visible false

            configure :status do
              pretty_value do
                "<span class=\"label label-#{bindings[:object].status_class}\">#{value.to_s.capitalize}</span>".html_safe
              end
            end

            edit do
              field :namespace
              field :name
              field :aws_access_key
              field :aws_secret_key
              field :seller
              field :merchant
              field :markets
              field :signature_method
              field :signature_version
              field :metadata
            end

            group :credentials do
              label 'Credentials'
            end

            configure :aws_access_key do
              group :credentials
            end

            configure :aws_secret_key do
              group :credentials
            end

            show do
              field :namespace
              field :name
              field :aws_access_key
              field :aws_secret_key
              field :seller
              field :merchant
              field :markets
              field :signature_method
              field :signature_version
              field :metadata
            end

            list do
              field :namespace
              field :name
              field :aws_access_key
              field :aws_secret_key
              field :seller
              field :merchant
              field :markets
              field :signature_method
              field :signature_version
              field :updated_at
            end

            fields :namespace, :name, :aws_access_key, :aws_secret_key, :seller, :merchant, :markets, :signature_method, :signature_version, :updated_at
          end
        end
      end
    end
  end
end
