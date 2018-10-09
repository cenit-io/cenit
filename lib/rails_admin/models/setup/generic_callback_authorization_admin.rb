module RailsAdmin
  module Models
    module Setup
      module GenericCallbackAuthorizationAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Security'
            weight 334
            label 'Generic Callback Authorization'
            register_instance_option :label_navigation do
              'Callback Authorization'
            end
            object_label_method { :custom_title }
            parent ::Setup::Authorization
            hierarchy_selectable true

            configure :namespace, :enum_edit

            configure :metadata, :json_value

            configure :status do
              pretty_value do
                "<span class=\"label label-#{bindings[:object].status_class}\">#{value.to_s.capitalize}</span>".html_safe
              end
            end

            edit do
              field :namespace
              field :name
              field :client
              field :callback_resolver
              field :parameters_signer
              field :parameters
              field :template_parameters
              field :metadata
            end

            show do
              field :namespace
              field :name
              field :status
              field :client
              field :callback_resolver
              field :parameters_signer
              field :parameters
              field :template_parameters
              field :metadata
              field :authorized_at
              field :_id
            end

            fields :namespace, :name, :status, :client, :updated_at
          end
        end

      end
    end
  end
end
