module RailsAdmin
  module Models
    module Setup
      module SchemaAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            weight 101
            object_label_method { :custom_title }
            navigation_label 'Definitions'

            configure :namespace, :enum_edit

            configure :code_warnings, :code_warnings

            configure :schema, :code do
              code_config do
                if bindings[:object].schema_type == :json_schema
                  {
                    mode: 'application/json'
                  }
                else
                  {
                    mode: 'application/xml'
                  }
                end
              end
            end

            edit do
              field :namespace, :enum_edit do
                read_only { !bindings[:object].new_record? }
              end

              field :uri do
                read_only { !bindings[:object].new_record? }
                html_attributes do
                  { cols: '74', rows: '1' }
                end
              end

              field :code_warnings
              field :schema

              field :schema_data_type do
                shared_read_only
                inline_edit false
                inline_add false
              end
            end

            show do
              field :namespace
              field :uri
              field :code_warnings
              field :schema
              field :schema_data_type

              field :_id
              field :created_at
              #field :creator
              field :updated_at
              #field :updater
            end

            fields :namespace, :uri, :schema_data_type, :updated_at
          end
        end

      end
    end
  end
end
