module Setup
  class AlgorithmParameter
    include CenitScoped
    # = Algorithm Parameter
    #
    # Define parameters that is possible pass to an algorithm

    build_in_data_type.referenced_by(:name)

    field :name, type: String
    field :type, type: String
    field :many, type: Boolean
    field :required, type: Boolean, default: true
    field :default, type: String

    embedded_in :algorithm, class_name: Setup::Algorithm.to_s, inverse_of: :parameters

    validates_presence_of :name

    validate do
      if type
        unless type.blank?
          errors.add(:type, 'is not valid') unless type_enum.include?(type)
        end
      end
      if required
        unless default.blank?
          errors.add(:default, 'is not allowed')
        end
      else
        unless default.blank?
          if type == 'string'
            self.default = "\"#{default}" unless default.start_with?('"')
            self.default = "#{default}\"" unless default.end_with?('"')
          end
          begin
            Mongoff::Validator.validate_instance(
              JSON.parse(default),
              schema: schema,
              data_type: self.class.data_type
            )
          rescue Exception => e
            errors.add(:default, e.message)
          end
        end
      end
      errors.blank?
    end

    def type_enum
      %w(integer number boolean string hash)
      # Setup::DataType.where(namespace: self.namespace).collect(&:custom_title)
      # Setup::Collection.reflect_on_all_associations(:has_and_belongs_to_many).collect { |r| r.name.to_s.singularize.to_title }
    end

    def schema
      sch =
        if type.blank?
          {}
        elsif %w(integer number boolean string).include?(type)
          {
            type: type
          }
        elsif type == 'hash'
          {
            type: 'object'
          }
        else
          {
            '$ref': Setup::Collection.reflect_on_association(type.to_s.downcase.tr(' ', '_').pluralize).klass.to_s
          }
        end.stringify_keys
      sch[:default] = default_json unless required
      sch = (many ? { type: 'array', items: sch } : sch)
      sch[:referenced] = true unless type.blank? || %w(integer number boolean string object).include?(type)
      sch.stringify_keys
    end

    def default_json
      if many
        []
      else
        case type
        when 'integer'
          default.to_i
        when 'number'
          default.to_f
        when 'boolean'
          default.to_b
        when 'string'
          default
        when 'hash'
          begin
            JSON.parse(default)
          rescue
            {}
          end
        else
          nil
        end
      end
    end

    def default_ruby
      if many
        '[]'
      else
        default.presence ||
          case type
          when 'integer'
            '0'
          when 'number'
            '0.0'
          when 'boolean'
            'false'
          when 'string'
            '""'
          when 'hash'
            '{}'
          else
            'nil'
          end
      end
    end

    def default_javascript
      if many
        '[]'
      else
        default.presence ||
          case type
          when 'integer'
            '0'
          when 'number'
            '0.0'
          when 'boolean'
            'false'
          when 'string'
            '""'
          when 'hash'
            '{}'
          else
            'false' #TODO V8 does not recognize null or undefined
          end
      end
    end
  end
end
