module Setup
  class CrossSharedCollection
    include CenitUnscoped
    include CollectionBehavior
    include HashField

    build_in_data_type.with(:name,
                            :shared_version,
                            :authors,
                            :summary,
                            :pull_parameters,
                            :dependencies,
                            :readme,
                            :pull_data,
                            :data,
                            :swagger_scpec,
                            *COLLECTING_PROPERTIES).referenced_by(:name, :shared_version)

    image_with ImageUploader
    field :logo_background, type: String

    field :shared_version, type: String
    embeds_many :authors, class_name: Setup::CrossCollectionAuthor.to_s, inverse_of: :shared_collection

    field :category, type: String
    field :summary, type: String

    embeds_many :pull_parameters, class_name: Setup::CrossCollectionPullParameter.to_s, inverse_of: :shared_collection
    has_and_belongs_to_many :dependencies, class_name: Setup::CrossSharedCollection.to_s, inverse_of: nil

    field :pull_count, type: Integer, default: 0

    hash_field :data, :pull_data, :swagger_spec

    validates_format_of :shared_version, with: /\A(0|[1-9]\d*)(\.(0|[1-9]\d*))*\Z/
    validates_length_of :shared_version, maximum: 255
    validates_presence_of :authors, :summary

    accepts_nested_attributes_for :authors, allow_destroy: true
    accepts_nested_attributes_for :pull_parameters, allow_destroy: true

    build_in_data_type.schema['properties'].each do |name, schema|
      if COLLECTING_PROPERTIES.include?(name.to_sym)
        edi_spec = schema['edi'] ||= {}
        edi_spec['discard'] = true
      end
    end

    default_scope -> { desc(:pull_count) }

    def hash_attribute_read(name, value)
      if name == 'data' && value.blank?
        generate_data
      else
        value
      end
    end

    def check_before_save
      super &&
        check_dependencies &&
        begin
          if present?
            self.data = {}
          end
          true
        end
    end

    def check_dependencies
      for_each_dependence([self]) do |dependence, stack|
        if stack.count { |d| d.name == dependence.name } > 1
          errors.add(:dependencies, "with circular reference #{stack.collect { |d| d.versioned_name }.join(' -> ')}")
          return false
        end
      end
      true
    end

    def for_each_dependence(stack = [], &block)
      dependencies.each do |dependence|
        stack << dependence
        dependence.for_each_dependence(stack, &block)
        block.call(dependence, stack)
        stack.pop
      end if block
    end

    def generate_data
      hash = {}
      COLLECTING_PROPERTIES.each do |property|
        if (items = send(property).collect(&:share_hash)).present?
          hash[property] = items
        end
      end
      hash
    end

    def data_with(parameters = {})
      hash_data = dependencies_data.deep_merge(data) { |_, val1, val2| Cenit::Utility.array_hash_merge(val1, val2) }
      hash_data.each do |key, values|
        next if Setup::Collection::NO_DATA_FIELDS.include?(key)
        hash = values.inject({}) do |hash, item|
          name =
            if (name = item['namespace'])
              { namespace: name, name: item['name'] }
            else
              item['name']
            end
          hash[name] = item; hash
        end
        hash_data[key] = hash.values.to_a unless hash.size == values.length
      end
      parameters.each do |id, value|
        if (pull_parameter = pull_parameters.where(id: id).first)
          pull_parameter.process_on(hash_data, value: value)
        end
      end
      hash_data
    end

    def dependencies_data(parameters = {})
      dependencies.inject({}) { |hash_data, dependency| hash_data.deep_merge(dependency.data_with(parameters)) { |_, val1, val2| Cenit::Utility.array_hash_merge(val1, val2) } }
    end
  end
end
