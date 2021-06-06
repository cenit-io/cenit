module Setup
  class Parameter
    include CenitScoped
    include JsonMetadata
    include ChangedIf

    build_in_data_type
      .with(:key, :value, :description, :metadata)
      .referenced_by(:key)
      .and(
        label: '{{key}}',
        properties: {
          parent_data_type: {
            referenced: true,
            '$ref': {
              namespace: 'Setup',
              name: 'DataType'
            },
            edi: {
              discard: true
            },
            virtual: true
          },
          parent: {
            type: 'object',
            edi: {
              discard: true
            },
            virtual: true
          },
          location: {
            type: 'string',
            edi: {
              discard: true
            },
            virtual: true
          }
        }
      )

    field :key, type: String, as: :name
    field :description, type: String
    field :value

    validates_presence_of :key

    def to_s
      "#{key}: #{value}"
    end

    def parent_relation
      @parent_relation ||= reflect_on_all_associations(:belongs_to).detect { |r| send(r.name) }
    end

    def location
      parent_relation&.inverse
    end

    def parent_model
      parent_relation&.klass
    end

    def parent
      (r = parent_relation) && send(r.name)
    end

    def parent_data_type
      parent_model&.data_type
    end

    class << self
      def stored_properties_on(record)
        stored = super
        %w(parent_data_type parent location).each { |prop| stored << prop }
        stored
      end
    end
  end
end
