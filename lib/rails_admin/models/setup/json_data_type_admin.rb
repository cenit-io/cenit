module RailsAdmin
  module Models
    module Setup
      module JsonDataTypeAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do |c|
            navigation_label 'Definitions'
            weight 111
            label 'Object Type'
            object_label_method { :custom_title }

            group :notifications do
              active false
            end

            group :behavior do
              label 'Behavior'
              active false
            end

            c.configure :title

            c.configure :name do
              read_only { !bindings[:object].new_record? }
            end

            c.configure :schema, :json_schema

            c.configure :schema_code, :json_schema do
              label 'Schema'
              help { 'Required' }
            end

            c.configure :storage_size, :decimal do
              pretty_value do
                if (objects = bindings[:controller].instance_variable_get(:@objects))
                  unless (max = bindings[:controller].instance_variable_get(:@max_storage_size))
                    bindings[:controller].instance_variable_set(:@max_storage_size, max = objects.collect { |data_type| data_type.storage_size }.max)
                  end
                  (bindings[:view].render partial: 'size_bar', locals: { max: max, value: bindings[:object].records_model.storage_size }).html_safe
                else
                  bindings[:view].number_to_human_size(value)
                end
              end
              read_only true
            end

            c.configure :before_save_callbacks do
              group :behavior
              inline_add false
              associated_collection_scope do
                Proc.new { |scope|
                  scope.where(:parameters.with_size => 1)
                }
              end
            end

            c.configure :records_methods do
              group :behavior
              inline_add false
            end

            c.configure :data_type_methods do
              group :behavior
              inline_add false
            end

            c.configure :slug

            edit do
              field :namespace, :enum_edit, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :name, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :schema_code
              field :title, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :slug
              field :observers do
                label 'Events'
                visible { !bindings[:object].new_record? }
              end
              group :notifications do
                field :email_notifications do
                  label 'E-Mails'
                  visible { !bindings[:object].new_record? }
                end
                field :web_hook_notifications do
                  label 'Web-Hooks'
                  visible { !bindings[:object].new_record? }
                end
                field :sms_notifications do
                  label 'SMS'
                  visible { !bindings[:object].new_record? }
                end
              end
              field :before_save_callbacks, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :records_methods, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :data_type_methods, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
            end

            list do
              field :namespace
              field :name
              field :slug
              field :storage_size
              field :updated_at
            end

            show do
              field :namespace
              field :title
              field :name
              field :slug
              field :storage_size
              field :schema
              field :before_save_callbacks
              field :records_methods
              field :data_type_methods

              field :_id
              field :created_at
              #field :creator
              field :updated_at
              #field :updater
            end

            fields :namespace, :name, :slug, :storage_size, :updated_at
          end
        end

      end
    end
  end
end
