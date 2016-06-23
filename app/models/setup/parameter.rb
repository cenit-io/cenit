module Setup
  class Parameter
    include CenitScoped
    include JsonMetadata

    build_in_data_type.with(:key, :value, :description, :metadata).referenced_by(:key)

    field :key, type: String, as: :name
    field :description, type: String

    validates_presence_of :key

    after_initialize { @value ||= attributes.delete('value') || '' } #TODO Remove after DB migration

    def configure
      parameter_config.save if parameter_config && parameter_config.changed?
    end

    def to_s
      "#{key}: #{value}"
    end

    def value
      parameter_config ? parameter_config.value : @value
    end

    def value=(value)
      value ||= ''
      if parameter_config
        parameter_config.value = value
      else
        @value = value
      end
    end

    def location
      (r = __metadata) && r.name
    end

    def parent_model
      (r = __metadata) && r.inverse_klass
    end

    def parent
      _parent
    end

    def parameter_config
      @parameter_config ||=
        if (r = __metadata)
          parent_field = r.inverse_of
          config =
            if new_record?
              Setup::ParameterConfig.new(parent_field => parent,
                                         location: location,
                                         name: name)
            else
              Setup::ParameterConfig.find_or_create_by(parent_field => parent,
                                                       location: location,
                                                       name: name)
            end
          config.value = @value if @value.present?
          config
        end
    end
  end
end
