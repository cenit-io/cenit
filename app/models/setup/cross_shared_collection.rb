module Setup
  class CrossSharedCollection
    include CenitUnscoped
    include CrossOrigin::CenitDocument
    include CollectionBehavior
    include Taggable
    include RailsAdmin::Models::Setup::CrossSharedCollectionAdmin

    origins -> { Cenit::MultiTenancy.tenant_model.current && :owner }, :shared

    default_origin :owner

    build_in_data_type.with(:title,
                            :name,
                            :shared_version,
                            :authors,
                            :summary,
                            :categories,
                            :pull_parameters,
                            :pull_asynchronous,
                            :pull_count,
                            :dependencies,
                            :readme,
                            :image,
                            :pull_data,
                            :data,
                            :swagger_spec,
                            *COLLECTING_PROPERTIES).embedding(:categories)
    build_in_data_type.discarding(:pull_data, *COLLECTING_PROPERTIES)
    build_in_data_type.referenced_by(:name, :shared_version)

    deny :new, :translator_update, :convert, :send_to_flow, :copy, :delete_all

    belongs_to :owner, class_name: Cenit::MultiTenancy.user_model_name, inverse_of: nil

    field :shared_version, type: String
    embeds_many :authors, class_name: Setup::CrossCollectionAuthor.to_s, inverse_of: :shared_collection

    field :category, type: String
    field :summary, type: String
    has_and_belongs_to_many :categories, class_name: Setup::Category.to_s, inverse_of: nil

    embeds_many :pull_parameters, class_name: Setup::CrossCollectionPullParameter.to_s, inverse_of: :shared_collection
    has_and_belongs_to_many :dependencies, class_name: Setup::CrossSharedCollection.to_s, inverse_of: nil

    field :pull_count, type: Integer, default: 0

    hash_field :data, :pull_data, :swagger_spec

    image_with ImageUploader
    field :logo_background, type: String

    field :installed, type: Boolean, default: false
    field :pull_asynchronous, type: Boolean, default: true

    before_validation do
      self.shared_version ||= '0.0.1'
      if authors.blank?
        authors.new(name: User.current.name, email: User.current.email)
      end
    end

    validates_format_of :shared_version, with: /\A(0|[1-9]\d*)(\.(0|[1-9]\d*))*\Z/
    validates_length_of :shared_version, maximum: 255
    validates_presence_of :authors, :summary

    accepts_nested_attributes_for :authors, allow_destroy: true
    accepts_nested_attributes_for :pull_parameters, allow_destroy: true

    default_scope -> { desc(:pull_count) }

    def installed?
      installed && persisted?
    end

    def shared?
      true
    end

    def hash_attribute_read(name, value)
      case name
      when 'data'
        installed? ? generate_data : value
      when 'pull_data'
        installed? ? value : data
      else
        value
      end
    end

    def check_before_save
      super &&
        ensure_shared_name &&
        check_dependencies &&
        validates_pull_parameters &&
        begin
          if installed
            self.data = {}
          end
          true
        end
    end

    def ensure_shared_name
      self.owner ||= Cenit::MultiTenancy.tenant_model.current.owner
      shared_name = Setup::CrossSharedName.find_or_create_by(name: name)
      if shared_name.owners.empty?
        shared_name.owners << owner
        shared_name.save
      elsif shared_name.owners.exclude?(owner)
        errors.add(:name, 'is already taken')
      end
      errors.blank?
    end

    def check_dependencies
      for_each_dependence([self]) do |dependence, stack|
        next unless stack.count { |d| d.name == dependence.name } > 1
        errors.add(:dependencies, "with circular reference #{stack.collect(&:versioned_name).join(' -> ')}")
        return false
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

    def validates_pull_parameters
      with_errors = false
      data =
        if installed
          if new_record?
            attributes[:pull_data] || attributes['pull_data']
          else
            self.pull_data
          end
        else
          self.data
        end
      data =
        begin
          JSON.parse(data.to_s)
        rescue
          {}
        end unless data.is_a?(Hash)
      pull_parameters.each do |pull_parameter|
        pull_parameter.process_on(data)
        with_errors ||= pull_parameter.errors.present?
      end
      if with_errors
        errors.add(:pull_parameters, 'is not valid')
        false
      else
        true
      end
    end

    def pull_model(name = 'pull_parameters')
      @pull_model ||= Mongoff::Model.for(
        data_type: self.class.data_type,
        schema: pull_schema,
        name: name,
        cache: false
      )
    end

    def pull_schema
      schema =
        {
          type: 'object',
          properties: properties = {},
          required: required = []
        }
      each_pull_parameter do |p|
        properties[p.id] = p.schema
        required << p.id if p.required
      end
      schema.stringify_keys
    end

    def each_pull_parameter(&block)
      pull_parameters.each { |p| block.call(p) }
      config_pull_parameters.each { |p| block.call(p) }
    end

    def config_pull_parameters
      unless @config_pull_parameters
        @config_pull_parameters = []
        clients = COLLECTING_PROPERTIES.detect { |p| reflect_on_association(p).klass == Setup::RemoteOauthClient }.to_s
        (pull_data[clients] || []).each do |client_data|
          client = Setup::RemoteOauthClient.new_from_json(client_data, add_only: true)
          Cenit::Utility.bind_references(client)
          if client.new_record? || ((current_user = User.current) && current_user.owns?(client.tenant))
            %w(identifier secret).each do |property|
              if client.send("get_#{property}").blank?
                p = Setup::CrossCollectionPullParameter.new(
                  _id: "config_#{@config_pull_parameters.size}",
                  label: "OAuth Client '#{client.name}' #{property.capitalize}",
                  type: 'string',
                  required: false,
                  description: I18n.t('admin.actions.pull.client_property_description', client_name: client.name, property: property)
                )
                p.properties_locations << Setup::PropertyLocation.new(
                  property_name: property,
                  location: { clients => client_data }
                )
                @config_pull_parameters << p
              end
            end
          end
        end
      end
      @config_pull_parameters
    end

    def pull_parameters?
      pull_parameters.present? || config_pull_parameters.present?
    end

    def generate_data
      hash = {}
      if installed?
        visited = Set.new
        COLLECTING_PROPERTIES.each do |property|
          r = reflect_on_association(property)
          next unless (items = pull_data[r.name.to_s])
          hash[r.name] = items.collect do |item|
            record = r.klass.data_type.new_from_json(item, add_only: true)
            visited << record
            record
          end
        end
        hash.each do |r, records|
          hash[r] = records.collect do |record|
            Cenit::Utility.bind_references(record, visited: visited)
            record.share_hash
          end
        end
      else
        hash = collecting_data
      end
      hash.delete('readme')
      clean_ids(hash)
    end

    def data_with(parameters = {})
      hash_data = dependencies_data.deep_merge(pull_data) { |_, val1, val2| Cenit::Utility.array_hash_merge(val1, val2) }
      parametrize(hash_data, parameters)
      hash_data['metadata'] = metadata unless hash_data.key?('metadata') && metadata.blank?
      hash_data
    end

    def parametrize(hash_data, parameters, options = {})
      each_pull_parameter do |pull_parameter|
        value = parameters[pull_parameter.id] || parameters[pull_parameter.id.to_s]
        pull_parameter.process_on(hash_data, options.merge(value: value))
      end
    end

    def dependencies_data(parameters = {})
      dependencies.inject({}) { |hash_data, dependency| hash_data.deep_merge(dependency.data_with(parameters)) { |_, val1, val2| Cenit::Utility.array_hash_merge(val1, val2) } }
    end

    def pulled(options = {})
      self.class.collection.find(_id: id).update_one('$inc' => { pull_count: 1 })
      install(options) if !installed && options[:install] && User.current_installer?
    end

    def reinstall(options = {})
      options[:collection] ||= self
      options[:add_dependencies] = true unless options.key?(:add_dependencies)
      install(options)
    end

    def install(options)
      collection = options[:collection]
      origin = options[:origin] || (self.origin == :default ? self.class.default_origin : self.origin)
      collection.add_dependencies if options[:add_dependencies]

      if collection.warnings.present?
        collection.save(add_dependencies: false) if collection.changed?
        collection.warnings.each do |warning|
          errors.add(:base, warning)
        end
        return false
      end

      pull_data = {}
      [:title, :readme].each do |field|
        if (value = send(field))
          pull_data[field] = value
        end
      end

      attributes = {}
      COLLECTING_PROPERTIES.each do |property|
        r = reflect_on_association(property)
        opts = { polymorphic: true }
        opts[:include_id] = lambda do |record|
          record.is_a?(Setup::CrossOriginShared) && record.shared?
        end
        pull_data[r.name] =
          if r.klass < Setup::CrossOriginShared
            if (ids = collection.send(r.foreign_key).dup).present?
              attributes[r.foreign_key] = ids
            end
            if r.klass.include?(Setup::SharedConfigurable)
              configuring_fields = r.klass.data_type.get_referenced_by + r.klass.configuring_fields.to_a
              configuring_fields = configuring_fields.collect(&:to_s)
              collection.send(r.name).collect do |record|
                { _id: record.id.to_s }.merge record.share_hash(opts).reject { |k, _| configuring_fields.exclude?(k) }
              end
            else
              collection.send(r.name).collect { |record| record.shared? ? { _id: record.id.to_s } : record.share_hash(opts) }
            end
          else
            collection.send(r.name).collect { |record| record.share_hash(opts) }
          end
        pull_data.delete_if { |_, value| value.blank? }
        send("#{property}=", [])
      end

      assign_attributes(attributes)
      self.metadata = collection.metadata
      pull_data.deep_stringify_keys!
      self.pull_data = pull_data

      self.installed = true
      self.skip_reinstall_callback = true
      if save(add_dependencies: false)
        collection.cross_to(origin, origin: :default)
        true
      end
    end

    def versioned_name
      "#{name}-#{shared_version}"
    end

    def save(options = {})
      @add_dependencies =
        if options.key?(:add_dependencies)
          options.delete(:add_dependencies)
        else
          @add_dependencies
        end
      if (result = super)
        reinstall(add_dependencies: false) unless !installed? || skip_reinstall_callback
        self.skip_reinstall_callback = false
      end
      result
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

    class << self
      def index_ignore_properties
        super + [:data]
      end
    end

    protected

    attr_accessor :skip_reinstall_callback

    def clean_ids(value)
      case value
      when Hash
        if value['_reference']
          Cenit::Utility.deep_remove(value, 'id')
        else
          h = {}
          value.each do |key, sub_value|
            h[key] = clean_ids(sub_value)
          end
          h
        end
      when Array
        value.collect { |sub_value| clean_ids(sub_value) }
      else
        value
      end
    end

  end
end
