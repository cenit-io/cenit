module Setup
  class Parameter
    include CenitScoped
    include JsonMetadata
    include ChangedIf

    build_in_data_type
      .with(:key, :value, :description, :metadata)
      .referenced_by(:key)
      .and({ label: '{{key}}' })

    deny :create

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
      (r = parent_relation) && r.inverse_name
    end

    def parent_model
      (r = parent_relation) && r.klass
    end

    def parent
      (r = parent_relation) && send(r.name)
    end

  end
end
