module RailsAdmin
  module Models
    module Setup
      module AuthorizationAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Security'
            navigation_icon 'fa fa-shield'
            weight 330
            object_label_method { :custom_title }
            configure :status do
              pretty_value do
                "<span class=\"label label-#{bindings[:object].status_class}\">#{value.to_s.capitalize}</span>".html_safe
              end
            end

            configure :namespace, :enum_edit

            configure :metadata, :json_value

            configure :_type do
              pretty_value do
                value.split('::').last.to_title
              end
            end

            edit do
              field :namespace
              field :name
              field :metadata
            end

            fields :namespace, :name, :status, :_type, :metadata, :updated_at
            show_in_dashboard false
            filter_fields :namespace, :name, :authorized, :_type, :metadata, :updated_at
          end
        end
      end
    end
  end
end
