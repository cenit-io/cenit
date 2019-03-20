module RailsAdmin
  module Models
    module Setup
      module FileDataTypeAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Definitions'
            weight 112
            label 'File Type'
            navigation_icon 'fa fa-file-o'
            object_label_method { :custom_title }

            configure :namespace, :enum_edit

            configure :file_store, :enum do
              enum do
                ::Cenit.file_stores.map { |fs| [fs.label, fs] }.to_h
              end
              visible do
                ::Cenit.file_stores.count > 1
              end
            end

            group :content do
              label 'Content'
            end

            group :behavior do
              label 'Behavior'
              active false
            end

            configure :storage_size, :decimal do
              pretty_value do
                if objects = bindings[:controller].instance_variable_get(:@objects)
                  unless max = bindings[:controller].instance_variable_get(:@max_storage_size)
                    bindings[:controller].instance_variable_set(:@max_storage_size, max = objects.collect { |data_type| data_type.records_model.storage_size }.max)
                  end
                  (bindings[:view].render partial: 'size_bar', locals: { max: max, value: bindings[:object].records_model.storage_size }).html_safe
                else
                  bindings[:view].number_to_human_size(value)
                end
              end
              read_only true
            end

            configure :validators do
              group :content
              inline_add false
            end

            configure :schema_data_type do
              group :content
              inline_add false
              inline_edit false
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

            configure :id_type do
              label 'ID Type'
            end

            edit do
              field :namespace, :enum_edit, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :name, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :id_type, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :title, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :slug
              field :validators, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :schema_data_type, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :before_save_callbacks, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :records_methods, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :data_type_methods, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
            end

            list do
              field :namespace
              field :name
              field :slug
              field :validators
              field :schema_data_type
              field :file_store
              field :storage_size
              field :updated_at
            end

            show do
              field :title
              field :name
              field :id_type
              field :slug
              field :validators
              field :file_store
              field :storage_size
              field :schema_data_type

              field :_id
              field :created_at
              #field :creator
              field :updated_at
              #field :updater
            end

            fields :namespace, :name, :slug, :storage_size, :updated_at

            filter_query_fields :namespace, :name
          end
        end
      end
    end
  end
end
