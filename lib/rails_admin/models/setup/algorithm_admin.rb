module RailsAdmin
  module Models
    module Setup
      module AlgorithmAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Compute'
            weight 400
            object_label_method { :custom_title }

            extra_associations do
              association = Mongoid::Relations::Metadata.new(
                name: :stored_outputs, relation: Mongoid::Relations::Referenced::Many,
                inverse_class_name: ::Setup::Algorithm.to_s, class_name: ::Setup::AlgorithmOutput.to_s
              )
              [RailsAdmin::Adapters::Mongoid::Association.new(association, abstract_model.model)]
            end

            configure :code, :code

            edit do
              field :namespace, :enum_edit, &RailsAdmin::Models::Setup::FieldsConfigAdmin.shared_non_editable
              field :name, &RailsAdmin::Models::Setup::FieldsConfigAdmin.shared_non_editable
              field :description, &RailsAdmin::Models::Setup::FieldsConfigAdmin.shared_non_editable
              field :parameters, &RailsAdmin::Models::Setup::FieldsConfigAdmin.shared_non_editable
              field :language
              field :code, :code do
                code_config do
                  {
                    mode: 'text/x-ruby'
                  }
                end
                help { 'Required' }
              end
              field :call_links do
                RailsAdmin::Models::Setup::FieldsConfigAdmin.shared_read_only
                visible { bindings[:object].call_links.present? }
              end
              field :store_output, &RailsAdmin::Models::Setup::FieldsConfigAdmin.shared_non_editable
              field :output_datatype, &RailsAdmin::Models::Setup::FieldsConfigAdmin.shared_non_editable
              field :validate_output, &RailsAdmin::Models::Setup::FieldsConfigAdmin.shared_non_editable
              field :tags
            end
            show do
              field :namespace
              field :name
              field :description
              field :language
              field :parameters
              field :code, :code do
                code_config do
                  {
                    mode: 'text/x-ruby',
                    readOnly: 'nocursor'
                  }
                end
              end
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
          end
        end

      end
    end
  end
end
