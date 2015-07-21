module Setup
  class SharedCollection
    include CenitUnscoped
    include Trackable
    include CollectionName

    Setup::Models.exclude_actions_for self, :new, :edit, :translator_update, :convert, :send_to_flow, :delete_all, :delete

    BuildInDataType.regist(self).with(:name, :shared_version, :authors, :summary, :description, :pull_parameters, :dependencies, :data).referenced_by(:name, :shared_version)

    belongs_to :shared_name, class_name: Setup::SharedName.to_s, inverse_of: nil

    mount_uploader :image, GridFsUploader
    field :name, type: String
    field :shared_version, type: String
    field :category, type: String
    field :description, type: String
    field :summary, type: String
    embeds_many :authors, class_name: Setup::CollectionAuthor.to_s, inverse_of: :shared_collection
    belongs_to :source_collection, class_name: Setup::Collection.to_s, inverse_of: nil
    has_and_belongs_to_many :connections, class_name: Setup::Connection.to_s, inverse_of: nil
    embeds_many :pull_parameters, class_name: Setup::CollectionPullParameter.to_s, inverse_of: :shared_collection
    has_and_belongs_to_many :dependencies, class_name: Setup::SharedCollection.to_s, inverse_of: nil

    field :data, type: Hash

    after_initialize do
      authors << Setup::CollectionAuthor.new(name: ::User.current.name, email: ::User.current.email) if new_record? && authors.empty?
    end

    attr_readonly :shared_version

    validates_presence_of :authors, :summary, :description
    validates_format_of :shared_version, with: /\A(0|[1-9]\d*)(\.(0|[1-9]\d*))*\Z/
    validates_length_of :shared_version, maximum: 255

    accepts_nested_attributes_for :authors, allow_destroy: true
    accepts_nested_attributes_for :pull_parameters, allow_destroy: true

    before_save :check_dependencies, :validate_configuration, :ensure_shared_name, :save_source_collection, :categorize

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
        if values = hash['connections']
          values.delete_if { |source_connection| !connections.detect { |c| c.name == source_connection['name'] } }
        end if hash
      end if connections.present?
      dependencies_hash_data = dependencies_data
      if pull_parameters.present?
        pull_parameters_enum = enum_for_pull_parameters
        pull_parameters.each do |pull_parameter|
          if pull_parameter.validate_configuration
            if (parameter = pull_parameter.parameter) && pull_parameters_enum.include?(parameter)
              pull_parameter.process_on(hash_data) || pull_parameter.process_on(dependencies_hash_data)
            else
              pull_parameter.errors.add(:base, 'is not valid')
            end
          end
        end
        errors.add(:pull_parameters, 'is not valid') if pull_parameters.any? { |pull_parameter| pull_parameter.errors.present? }
      end
      dependencies_hash_data.each do |entry, dependency_values|
        next if entry == 'name'
        if values = hash_data[entry]
          dependency_values.each { |value| values.delete(value) }
        end
      end
      hash_data.delete_if { |_, values| values.empty? }
      self.data = hash_data
      if errors.blank?
        if ::User.current.name.blank?
          ::User.current.name = authors.first.name
          ::User.current.save
        end
        true
      else
        false
      end
    end

    def ensure_shared_name
      if shared_name = Setup::SharedName.where(name: name).first
        if shared_name.owners.include?(creator)
          self.shared_name = shared_name
          validate_version
        else
          errors.add(:name, 'is already taken')
        end
      elsif errors.blank?
        if self.shared_name = Setup::SharedName.create(name: name)
          validate_version
        else
          errors.add(:name, 'is already taken')
        end
      end unless self.shared_name.present?
      errors.blank?
    end

    def validate_version
      if new_record? && major_version = orm_model.where(name: name).descending(:shared_version).first
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
      %w(Collection Library Translator)
    end

    def categorize
      shared = data.keys.select { |key| key != 'name' }
      self.category =
          shared.length == 1 && %w(libraries translators).include?(shared[0]) ? shared[0].singularize.capitalize : 'Collection'
      true
    end

    def owners
      shared_name.present? ? shared_name.owners : []
    end

    def versioned_name
      name + '-' + shared_version
    end

    def data_with(parameters = {})
      hash_data = dependencies_data.deep_merge(data) { |_, val1, val2| Cenit::Utility.array_hash_merge(val1, val2) }
      hash_data.each do |key, values|
        next if key == 'name'
        hash = values.inject({}) { |hash, item| hash[item['name']] = item; hash }
        hash_data[key] = hash.values.to_a unless hash.size == values.length
      end
      parameters.each do |id, value|
        if pull_parameter = pull_parameters.where(id: id).first
          pull_parameter.process_on(hash_data, value)
        end
      end
      hash_data
    end

    def dependencies_data(parameters = {})
      dependencies.inject({}) { |hash_data, dependency| hash_data.deep_merge(dependency.data_with(parameters)) { |_, val1, val2| Cenit::Utility.array_hash_merge(val1, val2) } }
    end

    def enum_for_pull_parameters
      collect_pull_parameters unless pull_parameters.present?
      (pull_parameters.collect(&:parameter) + source_pull_parameters_enum).uniq
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

    def source_pull_parameters_enum(source_collection = self.source_collection, connections = self.connections)
      enum = []
      if source_collection
        connections ||= []
        source_collection.connections.each do |connection|
          if connections.include?(connection)
            enum << CollectionPullParameter.parameter_for(connection, :url)
            [:headers, :parameters, :template_parameters].each do |property|
              enum += connection.send(property).collect { |value| CollectionPullParameter.parameter_for(connection, property, value.key) }
            end
          end
        end
        source_collection.webhooks.each do |webhook|
          [:headers, :parameters, :template_parameters].each do |property|
            enum += webhook.send(property).collect { |value| CollectionPullParameter.parameter_for(webhook, property, value.key) }
          end
        end
      end
      enum
    end

    protected

    def collect_dependencies_pull_parameters(hash = {})
      dependencies.each { |dependence| dependence.collect_dependencies_pull_parameters(hash) }
      pull_parameters.each { |pull_parameter| hash[pull_parameter.parameter] = pull_parameter }
      hash
    end
  end
end
