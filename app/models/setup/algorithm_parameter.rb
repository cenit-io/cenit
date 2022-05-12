module Setup
  class AlgorithmParameter
    include CenitScoped
    # = Algorithm Parameter
    #
    # Define parameters that is possible pass to an algorithm

    build_in_data_type.referenced_by(:name)

    field :name, type: String
    field :type, type: String
    field :many, type: Mongoid::Boolean
    field :required, type: Mongoid::Boolean, default: true
    field :default

    embedded_in :algorithm, class_name: Setup::Algorithm.to_s, inverse_of: :parameters

    validates_presence_of :name

    validates_format_of :name, with: /\A[a-zA-Z_][a-zA-Z_0-9]*\Z/

    validate do
      if type
        unless type.blank?
          errors.add(:type, 'is not valid') unless type_enum.include?(type)
        end
      end
      if required
        errors.add(:default, 'is not allowed on required parameters') unless default.nil?
      else
        unless default.nil?
          begin
            Mongoff::Validator.validate_instance(
              default,
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
      %w(integer number boolean string object)
      # Setup::DataType.where(namespace: self.namespace).collect(&:custom_title)
      # Setup::Collection.reflect_on_all_associations(:has_and_belongs_to_many).collect { |r| r.name.to_s.singularize.to_title }
    end

    def schema
      sch =
        if type.blank?
          {}
        elsif %w(integer number boolean string object).include?(type)
          {
            type: type
          }
        else
          {
            '$ref': Setup::Collection.reflect_on_association(type.to_s.downcase.tr(' ', '_').pluralize).klass.to_s
          }
        end.stringify_keys
      sch[:default] = default unless required
      sch = (many ? { type: 'array', items: sch } : sch)
      sch[:referenced] = true unless type.blank? || %w(integer number boolean string object).include?(type)
      sch.stringify_keys
    end

    def default_ruby
      default.inspect
    end

    def default_javascript
      default.to_json
    end
  end
end
