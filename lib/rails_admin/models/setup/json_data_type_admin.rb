module RailsAdmin
  module Models
    module Setup
      module JsonDataTypeAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Definitions'
            weight 111
            object_label_method { :custom_title }

            group :behavior do
              label 'Behavior'
              active false
            end

            configure :title

            configure :namespace, :enum_edit

            configure :name do
              read_only { !bindings[:object].new_record? }
            end

            configure :schema, :json_schema

            configure :schema_code, :json_schema do
              label 'Schema'
              help { 'Required' }
            end

            configure :storage_size, :decimal do
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

            configure :before_save_callbacks do
              group :behavior
              inline_add false
              associated_collection_scope do
                limit = (associated_collection_cache_all ? nil : 30)
                Proc.new { |scope| scope.where(:parameters.with_size => 1).limit(limit) }
              end
            end

            configure :records_methods do
              group :behavior
              inline_add false
            end

            configure :data_type_methods do
              group :behavior
              inline_add false
            end

            configure :slug

            edit do
              field :namespace, :enum_edit, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :name, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :schema_code
              field :title, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :slug
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

            filter_fields :namespace, :name
          end
        end

      end
    end
  end
end
