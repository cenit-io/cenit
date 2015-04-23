module Setup
  class SharedCollection
    include CenitUnscoped
    include Trackable

    Setup::Models.exclude_actions_for self, :new, :translator_update, :convert,  :send_to_flow, :delete_all

    BuildInDataType.regist(self).excluding(:image, :source_collection, :connections)

    mount_uploader :image, GridFsUploader
    field :name, type: String
    field :description, type: String
    belongs_to :source_collection, class_name: Setup::Collection.to_s, inverse_of: nil
    has_and_belongs_to_many :connections, inverse_of: nil
    embeds_many :pull_parameters, class_name: Setup::CollectionPullParameter.to_s, inverse_of: :shared_collection

    field :data, type: Hash

    validates_presence_of :name, :description
    validates_uniqueness_of :name

    accepts_nested_attributes_for :pull_parameters

    before_save :validate_configuration

    def data_with(parameters={})
      hash_data = data
      parameters.each do |parameter, value|
        process_parameter(hash_data, parameter, value)
      end
      hash_data
    end

    def validate_configuration
      hash_data = (source_collection.present? && source_collection.to_hash) || data || '{}'
      [hash_data, hash_data['connection_roles']].flatten.each do |hash|
        if values = hash['connections']
          values.delete_if { |source_connection| !connections.detect { |c| c.name == source_connection['name'] } }
        end if hash
      end if connections.present?
      if source_collection.present? && pull_parameters.present?
        pull_parameters_enum = enum_for_pull_parameters
        pull_parameters.each do |pull_parameter|
          if (parameter = pull_parameter.parameter) && pull_parameters_enum.include?(parameter)
            process_parameter(hash_data, parameter, nil, pull_parameter)
          else
            pull_parameter.errors.add(:parameter, 'is not valid')
          end
        end
        errors.add(:pull_parameters, 'is not valid') if pull_parameters.detect { |pull_parameter| pull_parameter.errors.present? }
      end
      self.data = hash_data
      errors.blank?
    end

    def enum_for_pull_parameters
      self.class.pull_parameters_enum_for(source_collection, connections)
    end

    class << self
      def pull_parameters_enum_for(source_collection, connections)
        enum = []
        if source_collection
          connections ||= []
          source_collection.connections.each do |connection|
            if connections.include?(connection)
              enum << "URL of '#{connection.name}'"
              enum += connection.headers.collect { |header| "On connection '#{connection.name}' header '#{header.key}'" }
              enum += connection.parameters.collect { |parameter| "On connection '#{connection.name}' parameter '#{parameter.key}'" }
              enum += connection.template_parameters.collect { |parameter| "On connection '#{connection.name}' template parameter '#{parameter.key}'" }
            end
          end
          source_collection.webhooks.each do |webhook|
            enum += webhook.headers.collect { |header| "On webhook '#{webhook.name}' header '#{header.key}'" }
            enum += webhook.parameters.collect { |parameter| "On webhook '#{webhook.name}' parameter '#{parameter.key}'" }
            enum += webhook.template_parameters.collect { |parameter| "On webhook '#{webhook.name}' template parameter '#{parameter.key}'" }
          end
        end
        enum
      end
    end

    private

    def process_parameter(hash_data, parameter, parameter_value, pull_parameter = nil)
      parameter = parameter[0..parameter.length - 2]
      if parameter.start_with?('URL')
        name = parameter.from(parameter.index("'") + 1)
        if values = hash_data['connections']
          if value = values.detect { |h| h['name'] == name }
            if parameter_value.nil?
              value.delete('url')
            else
              value['url'] = parameter_value
            end
          else
            pull_parameter.errors.add(:parameter, "connection '#{name}' not found") if pull_parameter
          end
        else
          pull_parameter.errors.add(:parameter, "no connections") if pull_parameter
        end
        return
      elsif parameter.start_with?(prefix = "On connection '")
        key = 'connections'
      else
        prefix = "On webhook '"
        key = 'webhooks'
      end
      name = parameter[prefix.length..parameter.index("'", prefix.length) - 1]
      parameters_key = (parameter[parameter.index("'", prefix.length) + 1..parameter.rindex("'") - 1].strip + 's').gsub(' ', '_')
      parameter = parameter[parameter.rindex("'") + 1..parameter.length]
      if values = hash_data[key]
        if value = values.detect { |h| h['name'] == name }
          if params = value[parameters_key]
            if param = params.detect { |h| h['key'] == parameter }
              if parameter_value.nil?
                param.delete('value')
              else
                param['value'] = parameter_value
              end
            else
              pull_parameter.errors.add(:parameter, "with #{parameters_key.chop} '#{parameter}' not defined on #{key.chop} #{name}") if pull_parameter
            end
          else
            pull_parameter.errors.add(:parameter, "with name '#{name}' not containing #{parameters_key}") if pull_parameter
          end
        else
          pull_parameter.errors.add(:parameter, "with name '#{name}' not found on shared data") if pull_parameter
        end
      else
        pull_parameter.errors.add(:parameter, "with key '#{key}' not found on shared data") if pull_parameter
      end
    end
  end
end
