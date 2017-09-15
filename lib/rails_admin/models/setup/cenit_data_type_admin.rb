module RailsAdmin
  module Models
    module Setup
      module CenitDataTypeAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Definitions'
            weight 113
            label 'Cenit Type'
            object_label_method { :custom_title }

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

            configure :slug

            configure :schema, :json_schema

            edit do
              field :namespace do
                read_only true
              end
              field :name do
                read_only { !bindings[:object].build_in.nil? }
              end
              field :slug
              field :storage_size
            end

            show do
              field :title
              field :namespace
              field :name
              field :slug
              field :storage_size
              field :schema

              field :_id
              field :created_at
              field :updated_at
            end

            fields :namespace, :name, :slug, :storage_size, :updated_at
          end
        end

      end
    end
  end
end
