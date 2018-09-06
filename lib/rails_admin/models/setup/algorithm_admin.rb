module RailsAdmin
  module Models
    module Setup
      module AlgorithmAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Compute'
            navigation_icon 'fa fa-cog'
            weight 400
            object_label_method { :custom_title }

            extra_associations do
              association = ::Mongoid::Relations::Metadata.new(
                name: :stored_outputs, relation: ::Mongoid::Relations::Referenced::Many,
                inverse_class_name: ::Setup::Algorithm.to_s, class_name: ::Setup::AlgorithmOutput.to_s
              )
              [RailsAdmin::Adapters::Mongoid::Association.new(association, abstract_model.model)]
            end

            configure :namespace, :enum_edit

            configure :code_warning do
              read_only true
              help ''
              warning = proc do
                bindings[:view].render partial: 'code_warnings'
              end
              pretty_value(&warning)
              formatted_value(&warning)
            end

            configure :code, :code do
              help { 'Required' }
              code_config do
                {
                  mode: case bindings[:object].language
                        when :php
                          'text/x-php'
                        when :javascript
                          'text/javascript'
                        when :python
                          'text/x-python'
                        else
                          'text/x-ruby'
                        end
                }
              end
            end

            configure :language do
              help 'Required'
            end

            edit do
              field :namespace, :enum_edit, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :name, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :description, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :parameters, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :language, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :code_warning do
                visible do
                  !bindings[:object].new_record?
                end
              end
              field :code
              field :call_links do
                shared_read_only
                visible { bindings[:object].call_links.present? }
              end
              field :store_output, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :output_datatype, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :validate_output, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :tags, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
            end
            show do
              field :namespace
              field :name
              field :description
              field :language
              field :parameters
              field :code_warning
              field :code
              field :call_links
              field :tags
              field :_id

              field :stored_outputs
            end

            list do
              field :namespace
              field :name
              field :description
              field :language
              field :tags
              field :updated_at
            end

            fields :namespace, :name, :description, :language, :parameters, :call_links, :tags

            filter_query_fields :namespace, :name
          end
        end

      end
    end
  end
end
