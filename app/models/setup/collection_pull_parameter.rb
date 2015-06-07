module Setup
  class CollectionPullParameter < ReqRejValidator
    include CenitUnscoped

    BuildInDataType.regist(self)

    field :type, type: Symbol
    field :name, type: String
    field :label, type: String
    field :property, type: Symbol
    field :key, type: Symbol
    field :parameter, type: String

    embedded_in :shared_collection, class_name: Setup::SharedCollection.to_s, inverse_of: :pull_parameters

    validates_presence_of :label
    validates_length_of :label, maximum: 255
    validates_uniqueness_of :parameter

    before_save :validate_configuration

    def validate_configuration
      if parameter.present?
        CollectionPullParameter.hash_parameter(parameter).each do |key, value|
          try("#{key}=", value)
        end
      else
        self.parameter = CollectionPullParameter.generate_parameter(type, name, property, key)
      end
      !requires(:type, :name, :property, :parameter)
    end

    def process_on(hash_data, parameter_value = nil)
      errors.clear
      unless key.present?
        if values = hash_data[type.to_s.downcase.pluralize]
          if value = values.detect { |h| h['name'] == name.to_s }
            if parameter_value.nil?
              value.delete(property.to_s)
            else
              value[property.to_s] = parameter_value
            end
          else
            errors.add(:base, "#{type} '#{name}' not found")
          end
        else
          errors.add(:base, "no #{type.to_s.pluralize}")
        end
        return errors.blank?
      end
      values_key = self.type.to_s.downcase.pluralize
      if values = hash_data[values_key]
        if value = values.detect { |h| h['name'] == name }
          if params = value[property.to_s]
            if param = params.detect { |h| h['key'] == key.to_s }
              if parameter_value.nil?
                param.delete('value')
              else
                param['value'] = parameter_value
              end
            else
              errors.add(:base, "with #{property.chop} '#{key}' not defined on #{values_key.chop} #{name}") if pull_parameter
            end
          else
            errors.add(:base, "with name '#{name}' not containing #{property}")
          end
        else
          errors.add(:base, "with name '#{name}' not found on shared data")
        end
      else
        errors.add(:base, "with key '#{values_key}' not found on shared data")
      end
      errors.blank?
    end

    class << self

      def parameter_for(obj, property, key = nil)
        generate_parameter(obj.class.to_s, obj.try(:name), property, key)
      end

      def generate_parameter(type, name, property, key = nil)
        if type.present? && name.present? && property.present?
          p = "#{type.to_s.split('::').last.downcase} '#{name}'"
          if key.present?
            "On #{p} #{property.to_s.singularize.gsub('_', ' ')} '#{key}'"
          else
            "#{property.to_s.upcase} of #{p}"
          end
        else
          nil
        end
      end

      def hash_parameter(parameter)
        hash = {}
        parameter = parameter[0..parameter.length - 2]
        if parameter.start_with?('On ')
          hash['type'] =
            if parameter.start_with?(prefix = "On connection '")
              'connection'
            else
              prefix = "On webhook '"
              'webhook'
            end
          hash['name'] = parameter[prefix.length..parameter.index("'", prefix.length) - 1]
          hash['property'] = (parameter[parameter.index("'", prefix.length) + 1..parameter.rindex("'") - 1].strip + 's').gsub(' ', '_')
          hash['key'] = parameter[parameter.rindex("'") + 1..parameter.length]
        else
          parameter = parameter.split(' of ')
          hash['property'] = parameter[0].downcase
          hash['type'], hash['name'] = parameter[1].split(" '")
        end
        hash
      rescue
        hash
      end
    end
  end
end
