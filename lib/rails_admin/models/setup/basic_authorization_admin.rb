module RailsAdmin
  module Models
    module Setup
      module BasicAuthorizationAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Security'
            weight 331
            register_instance_option :label_navigation do
              'Basic'
            end
            object_label_method { :custom_title }

            configure :namespace, :enum_edit

            configure :status do
              pretty_value do
                "<span class=\"label label-#{bindings[:object].status_class}\">#{value.to_s.capitalize}</span>".html_safe
              end
            end

            configure :metadata, :json_value

            group :credentials do
              label 'Credentials'
            end

            configure :username do
              group :credentials
            end

            configure :password do
              group :credentials
            end

            show do
              field :namespace
              field :name
              field :status
              field :username
              field :password
              field :metadata
              field :_id
            end

            edit do
              field :namespace
              field :name
              field :username
              field :password
            end

            fields :namespace, :name, :status, :username, :password, :updated_at
          end
        end
      end
    end
  end
end
