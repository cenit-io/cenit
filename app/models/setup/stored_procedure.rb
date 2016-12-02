module Setup
  class StoredProcedure
    include SnippetCode
    include NamespaceNamed

    field :description, type: String
    field :language, type: String
    field :store_output, type: Boolean
    field :validate_output, type: Boolean

    embeds_many :parameters, class_name: Setup::AlgorithmParameter.to_s, inverse_of: :algorithm
    belongs_to :output_datatype, class_name: Setup::DataType.to_s, inverse_of: nil

    build_in_data_type.referenced_by(:namespace, :name, :language)

    accepts_nested_attributes_for :parameters, allow_destroy: true

    validates_format_of :name, with: /\A[a-z]([a-z]|_|\d)*\Z/

    def language_enum
      [:NodeJS, :Ruby, :Python, :PHP]
    end

    rails_admin do
      navigation_label 'Compute'
      object_label_method { :custom_title }
      visible true
      weight 401

      extra_associations do
        association = Mongoid::Relations::Metadata.new(
          name: :stored_outputs, relation: Mongoid::Relations::Referenced::Many,
          inverse_class_name: Setup::Algorithm.to_s, class_name: Setup::AlgorithmOutput.to_s
        )
        [RailsAdmin::Adapters::Mongoid::Association.new(association, abstract_model.model)]
      end

      fields :namespace, :name, :description, :parameters, :language

      edit do
        field :namespace, :enum_edit
        field :name
        field :description
        field :parameters
        field :language do
          partial "form_languages"
        end
        field :code, :code do
          help { 'Required' }
        end
        field :store_output
        field :output_datatype
        field :validate_output
      end
    end

    def configuration_schema
      schema = {
        type: 'object',
        properties: properties = {},
        required: parameters.select(&:required).collect(&:name)
      }
      parameters.each { |p| properties[p.name] = p.schema }
      schema.stringify_keys
    end

    def configuration_model
      @mongoff_model ||= Mongoff::Model.for(
        data_type: self.class.data_type,
        schema: configuration_schema,
        name: 'Setup::StoredProcedure::Config',
        cache: false
      )
    end

  end
end