module Setup
  class AlgorithmParameter
    include CenitScoped
    include RailsAdmin::Models::Setup::AlgorithmParameterAdmin
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
        if type.blank?
          self.type = nil
        else
          errors.add(:type, 'is not valid') unless type_enum.include?(type)
        end
      end
      if required
        if default.blank?
          self.default = nil
        else
          errors.add(:default, 'is not allowed')
        end
      else
        self.default ||= DEFAULTS[type]
      end
      errors.blank?
    end

    DEFAULTS =
      {
        integer: 0,
        number: 0.0,
        boolean: false,
        string: '',
        nil => nil
      }

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
      sch[:default] = default || DEFAULTS[type] unless required
      sch = (many ? { type: 'array', items: sch } : sch)
      sch[:referenced] = true unless type.blank? || %w(integer number boolean string object).include?(type)
      sch.stringify_keys
    end
    
  end
end
