module Setup
  class SharedCollection
    include CenitUnscoped
    include Trackable
    include CollectionName

    deny :copy, :new, :edit, :translator_update, :convert, :send_to_flow, :delete_all, :delete, :import

    build_in_data_type.with(:name, :shared_version, :authors, :summary, :pull_parameters, :dependencies, :data, :readme, :swagger_json).referenced_by(:name, :shared_version)

    belongs_to :shared_name, class_name: Setup::SharedName.to_s, inverse_of: nil

    mount_uploader :image, ImageUploader
    field :name, type: String
    field :shared_version, type: String
    field :logo_background, type: String
    field :category, type: String
    field :description, type: String
    field :summary, type: String
    embeds_many :authors, class_name: Setup::CollectionAuthor.to_s, inverse_of: :shared_collection
    belongs_to :source_collection, class_name: Setup::Collection.to_s, inverse_of: nil
    has_and_belongs_to_many :connections, class_name: Setup::Connection.to_s, inverse_of: nil
    embeds_many :pull_parameters, class_name: Setup::CollectionPullParameter.to_s, inverse_of: :shared_collection
    has_and_belongs_to_many :dependencies, class_name: Setup::SharedCollection.to_s, inverse_of: nil

    field :pull_count, type: Integer, default: 0
    field :readme, type: String
    field :data
    field :swagger_json, type: String

    default_scope -> { desc(:pull_count) }

    before_validation do
      authors << Setup::CollectionAuthor.new(name: ::User.current.name, email: ::User.current.email) if authors.empty?
    end

    validates_presence_of :authors, :summary
    validates_format_of :shared_version, with: /\A(0|[1-9]\d*)(\.(0|[1-9]\d*))*\Z/
    validates_length_of :shared_version, maximum: 255

    accepts_nested_attributes_for :authors, allow_destroy: true
    accepts_nested_attributes_for :pull_parameters, allow_destroy: true

    attr_reader :relocated

    after_initialize do
      pull_parameters.each { |pp| @relocated = pp.relocate || @relocated }
    end

    before_save :hook, :check_ready, :check_dependencies, :validate_configuration, :ensure_shared_name, :save_source_collection, :categorize, :sanitize_data, :on_saving

    def pulled(options = {})
      self.class.collection.find(_id: id).update_one('$inc' => { pull_count: 1 })
    end

    def hook
      true
    end

    def check_ready
      ready_to_save?
    end

    def ready_to_save?
      !(@_selecting_connections || @_selecting_dependencies)
    end

    def can_be_restarted?
      ready_to_save?
    end

    def read_attribute(name)
      value = super
      if name.to_s == 'data' && value.is_a?(String)
        attributes['data'] = value = JSON.parse(value) rescue value
      end
      value
    end

    def write_attribute(name, value)
      super
      case name.to_s
      when 'data'
        if (readme = data.delete('readme')).present?
          self.readme = readme
        end unless @source_readme
      when 'source_collection_id'
        if (readme = source_collection && source_collection.readme).present?
          @source_readme = true
          self.readme = readme
        end
      end if changed_attributes.has_key?(name)
    end

    def sanitize_data
      data = self.data
      data = JSON.parse(data) unless data.is_a?(Hash)
      #Stringify parameter values
      %w(connections webhooks).each do |entry|
        (data[entry] || []).each do |e|
          %w(headers parameters template_parameters).each do |params_key|
            if params = e[params_key]
              params.each { |param| param['value'] = param['value'].to_s }
            end
          end
        end
      end
      self.data = data
      errors.blank?
    end

    attr_accessor :pulling

    def on_saving
      attributes['data'] = attributes['data'].to_json unless attributes['data'].is_a?(String)
      if (changed_value = changed_attributes['data']) &&
        (changed_value.is_a?(String) || (changed_value = changed_value.to_json)) &&
        attributes['data'] == changed_value
        changed_attributes.delete('data')
      else
        changed_attributes['data'] = changed_value
      end
      changed_attributes.keys.each do |attr|
        reset_attribute!(attr) if %w(shared_version).include?(attr) || (%w(pull_count).include?(attr) && !pulling)
      end unless Account.current && Account.current_super_admin?
      true
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

    def validate_configuration
      hash_data = (source_collection.present? && source_collection.share_hash) || data || {}
      [hash_data, hash_data['connection_roles']].flatten.each do |hash|
        if (values = hash['connections'])
          values.delete_if { |source_connection| !connections.detect { |c| c.name == source_connection['name'] } }
        end if hash
      end if connections.present?
      dependencies_hash_data = dependencies_data
      if pull_parameters.present?
        pull_parameters.each do |pull_parameter|
          pull_parameter.process_on(hash_data, keep_value: true) ||
            pull_parameter.process_on(dependencies_hash_data, keep_value: true)
        end
        errors.add(:pull_parameters, 'is not valid') if pull_parameters.any? { |pull_parameter| pull_parameter.errors.present? }
      end
      hash_data.each do |entry, values|
        next if Setup::Collection::NO_DATA_FIELDS.include?(entry) || values.blank?
        if (dependency_values = dependencies_hash_data[entry]).present?
          model = "Setup::#{entry.singularize.camelize}".constantize rescue nil
          if model
            values.each do |value|
              criteria = {}
              model.data_type.get_referenced_by.each do |field|
                if (v = value[field.to_s])
                  criteria[field.to_s] = v
                end
              end
              values.delete(value) if (dependency_value = dependency_values.detect { |v| Cenit::Utility.match?(v, criteria) }) && value == dependency_value
            end
          end
        end
      end
      hash_data.delete_if { |_, values| values.empty? }
      self.data = hash_data
      if errors.blank?
        if ::User.current.name.blank?
          ::User.current.name = authors.first.name
          ::User.current.save
        end
        if (data_readme = hash_data.delete('readme')) && readme.blank?
          self.readme = data_readme
        end
        true
      else
        false
      end
    rescue Exception => ex
      errors.add(:base, ex.message)
      false
    end

    def ensure_shared_name
      if (shared_name = Setup::SharedName.where(name: name).first)
        if shared_name.owners.include?(creator)
          self.shared_name = shared_name
          validate_version
        else
          errors.add(:name, 'is already taken')
        end
      elsif errors.blank?
        if (self.shared_name = Setup::SharedName.create(name: name))
          validate_version
        else
          errors.add(:name, 'is already taken')
        end
      end unless self.shared_name.present?
      errors.blank?
    end

    def validate_version
      if new_record? && (major_version = orm_model.where(name: name).descending(:shared_version).first)
        errors.add(:shared_version, "must be greater than #{major_version.shared_version}") if shared_version <= major_version.shared_version
      end
    end

    def save_source_collection
      if source_collection && source_collection.new_record?
        source_collection.name = name unless source_collection.name.present?
        source_collection.save
      end
      true
    end

    def category_enum
      %w(Collection Translator Algorithm)
    end

    def categorize
      shared = data.keys.select { |key| Setup::Collection::NO_DATA_FIELDS.exclude?(key) }
      self.category =
        shared.length == 1 && %w(translators algorithms).include?(shared[0]) ? shared[0].singularize.capitalize : 'Collection'
      true
    end

    def owners
      shared_name.present? ? shared_name.owners : []
    end

    def versioned_name
      "#{name}-#{shared_version}"
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

    def collect_pull_parameters
      @dependencies_cache ||= Set.new
      if dependencies.any? { |d| !@dependencies_cache.include?(d) } || @dependencies_cache.any? { |d| !dependencies.include?(d) }
        self.pull_parameters = []
        collect_dependencies_pull_parameters.values.each do |pull_parameter|
          self.pull_parameters << Setup::CollectionPullParameter.new(pull_parameter.attributes)
        end
      end
    end


    class << self

      def find_by_id(*args)
        name = (args[0] || '').split('-')
        version = name.pop
        if name.empty?
          name = version
          version = nil
        else
          name = name.join('-')
        end
        criteria = { name: name }
        criteria[:shared_version] = version if version
        where(criteria).desc(:shared_version).first
      end
    end

    Setup::Collection.reflect_on_all_associations(:has_and_belongs_to_many).each do |relation|
      class_eval("def data_#{relation.name}(options = {})
          items_data = data['#{relation.name}'] || []
          limit = options[:limit] || items_data.length
          c = 0
          items_data.collect do |item_data|
            if c > limit
              nil
            else
              c += 1
              #{relation.klass}.new_from_json(item_data)
            end
          end
        end")
    end

    def cross
      cross_shared = Setup::CrossSharedCollection.new

      cross_shared.name = name
      cross_shared.shared_version = shared_version
      authors.each do |author|
        cross_shared.authors.new(name: author.name,
                                 email: author.email)
      end

      cross_shared.category = category
      cross_shared.summary = summary

      pull_parameters.each do |pp|
        cross_shared.pull_parameters.new(label: pp.label,
                                         location: pp.location,
                                         property_name: pp.property_name)
      end
      dependencies.each do |d|
        cross_shared.dependencies << Setup::CrossSharedCollection.where(name: d.name, shared_version: d.shared_version).first
      end

      cross_shared.pull_count = pull_count

      cross_shared.data = data

      cross_shared.image = image
      cross_shared.logo_background = logo_background

      cross_shared.save
    end

    protected

    def collect_dependencies_pull_parameters(hash = {})
      dependencies.each { |dependence| dependence.collect_dependencies_pull_parameters(hash) }
      pull_parameters.each { |pull_parameter| hash[pull_parameter.parameter] = pull_parameter }
      hash
    end
  end
end
