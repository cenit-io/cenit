module Setup
  class SharedCollection
    include CenitUnscoped

    Setup::Models.exclude_actions_for self, :new

    mount_uploader :image, GridFsUploader
    field :name, type: String
    field :description, type: String
    field :data, type: String

    embeds_many :pull_parameters, class_name: Setup::CollectionPullParameter.to_s, inverse_of: :shared_collection

    validates_presence_of :name, :description, :data
    validates_uniqueness_of :name

    accepts_nested_attributes_for :pull_parameters

    before_save :validate_configuration

    def data_with(parameters={})
      hash_data = JSON.parse(data)
      parameters.each do |parameter, value|
        process_parameter(hash_data, parameter, value)
      end
      hash_data
    end

    def validate_configuration
      if pull_parameters.present?
        hash_data = JSON.parse(data)
        pull_parameters.each do |pull_parameter|
          if (parameter = pull_parameter.parameter) #TODO Validate parameter format
            process_parameter(hash_data, parameter, nil, pull_parameter)
          else
            pull_parameter.errors.add(:parameter, 'is not valid')
          end
        end
        if pull_parameters.detect { |pull_parameter| pull_parameter.errors.present? }
          errors.add(:pull_parameters, 'is not valid')
        else
          self.data = hash_data.to_json
        end
      end
      errors.blank?
    end

    class << self
      def pull_parameters_enum_for(collection)
        enum = []
        collection.connections.each do |connection|
          enum += connection.headers.collect { |header| "On connection '#{connection.name}' header '#{header.key}'" }
          enum += connection.parameters.collect { |parameter| "On connection '#{connection.name}' parameter '#{parameter.key}'" }
        end
        collection.webhooks.each do |webhook|
          enum += webhook.headers.collect { |header| "On webhook '#{webhook.name}' header '#{header.key}'" }
          enum += webhook.parameters.collect { |parameter| "On webhook '#{webhook.name}' parameter '#{parameter.key}'" }
        end
        enum
      end
    end

    private

    def process_parameter(hash_data, parameter, parameter_value, pull_parameter = nil)
      parameter = parameter[0..parameter.length - 2]
      if parameter.start_with?(prefix = "On connection '")
        key = 'connections'
      else
        prefix = "On webhook '"
        key = 'webhooks'
      end
      name = parameter[prefix.length..parameter.index("'", prefix.length) - 1]
      parameters_key = parameter[parameter.index("'", prefix.length) + 1..parameter.rindex("'") - 1].strip + 's'
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
