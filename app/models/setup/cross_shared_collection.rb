module Setup
  class CrossSharedCollection
    include CenitUnscoped
    include CollectionBehavior
    include HashField

    build_in_data_type.with(:name,
                            :shared_version,
                            :authors,
                            :summary,
                            :category,
                            :pull_parameters,
                            :dependencies,
                            :readme,
                            :pull_data,
                            :data,
                            :swagger_spec,
                            *COLLECTING_PROPERTIES).referenced_by(:name, :shared_version)

    deny :new, :translator_update, :convert, :send_to_flow, :copy, :delete_all

    field :shared_version, type: String
    embeds_many :authors, class_name: Setup::CrossCollectionAuthor.to_s, inverse_of: :shared_collection

    field :category, type: String
    field :summary, type: String

    embeds_many :pull_parameters, class_name: Setup::CrossCollectionPullParameter.to_s, inverse_of: :shared_collection
    has_and_belongs_to_many :dependencies, class_name: Setup::CrossSharedCollection.to_s, inverse_of: nil

    field :pull_count, type: Integer, default: 0

    hash_field :data, :pull_data, :swagger_spec

    image_with ImageUploader
    field :logo_background, type: String

    field :installed, type: Boolean, default: false

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

    def installed?
      installed.present?
    end

    def shared?
      true
    end

    def hash_attribute_read(name, value)
      case name
      when 'data'
        installed ? generate_data : value
      when 'pull_data'
        installed ? value : data
      else
        value
      end
    end

    def check_before_save
      super &&
        check_dependencies &&
        begin
          self.data = {} if installed
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
      hash = collecting_data
      hash = pull_data.merge(hash)
      hash.delete('readme')
      hash
    end

    def data_with(parameters = {})
      hash_data = dependencies_data.deep_merge(pull_data) { |_, val1, val2| Cenit::Utility.array_hash_merge(val1, val2) }
      pull_parameters.each do |pull_parameter|
        pull_parameter.process_on(hash_data, value: parameters[pull_parameter.id] || parameters[pull_parameter.id.to_s])
      end
      hash_data
    end

    def dependencies_data(parameters = {})
      dependencies.inject({}) { |hash_data, dependency| hash_data.deep_merge(dependency.data_with(parameters)) { |_, val1, val2| Cenit::Utility.array_hash_merge(val1, val2) } }
    end

    def pulled(options = {})
      self.class.collection.find(_id: id).update_one('$inc' => { pull_count: 1 })
      if !installed && options[:install] && User.current_installer?
        self.pull_data = {}
        pull_data[:readme] = readme if readme.present?
        (collection = options[:collection]).cross(:shared)
        attributes = {}
        COLLECTING_PROPERTIES.each do |property|
          send("#{property}=", [])
          r = reflect_on_association(property)
          opts = { polymorphic: true }
          pull_data[r.name] =
            if r.klass.include?(Setup::CrossOriginShared)
              if (ids = collection.send(r.foreign_key)).present?
                attributes[r.foreign_key]= ids
              end
              if r.klass.include?(Setup::SharedConfigurable)
                configuring_fields = r.klass.data_type.get_referenced_by + r.klass.configuring_fields.to_a
                configuring_fields = configuring_fields.collect(&:to_s)
                collection.send(r.name).collect do |record|
                  { _id: record.id.to_s }.merge record.share_hash(opts).reject { |k, _| configuring_fields.exclude?(k) }
                end
              else
                collection.send(r.name).collect { |record| { _id: record.id.to_s } }
              end
            else
              collection.send(r.name).collect { |record| record.share_hash(opts) }
            end
          pull_data.delete_if { |_, value| value.blank? }
        end
        assign_attributes(attributes)
        pull_parameters.each { |pull_parameter| pull_parameter.process_on(pull_data) }
        self.installed = true
        save(add_dependencies: false)
      end
    end

    def versioned_name
      "#{name}-#{shared_version}"
    end

    def save(options = {})
      @add_dependencies =
        if options.has_key?(:add_dependencies)
          options.delete(:add_dependencies)
        else
          @add_dependencies
        end
      super
    end

    def method_missing(symbol, *args)
      if (match = /\Adata_(.+)\Z/.match(symbol.to_s)) &&
        COLLECTING_PROPERTIES.include?(relation_name = match[1].to_sym) &&
        ((args.length == 0 && (options = {})) || args.length == 1 && (options = args[0]).is_a?(Hash))
        if (items = send(relation_name)).present?
          items
        else
          relation = reflect_on_association(relation_name)
          items_data = pull_data[relation.name] || []
          limit = options[:limit] || items_data.length
          c = 0
          items_data.collect do |item_data|
            if c > limit
              nil
            else
              c += 1
              relation.klass.new_from_json(item_data)
            end
          end
        end
      else
        super
      end
    end
  end
end
