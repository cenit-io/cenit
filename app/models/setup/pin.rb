module Setup
  class Pin
    include CenitScoped
    include DynamicValidators
    include RailsAdmin::Models::Setup::PinAdmin

    build_in_data_type

    deny :copy

    class_attribute :models

    field :record_model, type: String

    self.models = {}

    Setup::Collection.reflect_on_all_associations(:has_and_belongs_to_many).each do |r|
      if (klass = r.klass).include?(Mongoid::Tracer)
        models[klass] =
          {
            model_name: r.name.to_s.singularize.capitalize.gsub('_', ' '),
            property: property = r.name.to_s.singularize.to_sym
          }
        belongs_to property, class_name: klass.to_s, inverse_of: nil
      end
    end

    field :version, type: Integer

    validates_uniqueness_in_presence_of *models.values.collect { |h| "#{h[:property]}_id".to_sym }

    before_save do
      errors.add(:record_model, "can't be blank") unless record_model.present?
      errors.add(:version, "can't be blank") unless version.present?
      if errors.blank?
        record_property = nil
        record = nil
        self.class.models.values.each do |m_data|
          record_property = m_data[:property] if m_data[:model_name] == record_model
          if record_property && (value = send(record_property))
            if m_data[:model_name] == record_model
              record = value
            else
              send("#{m_data[:property]}=", nil)
            end
          end
        end
        errors.add(record_property, "can't be blank") unless record
      end
      errors.blank?
    end

    def record_model_enum
      self.class.models.values.collect { |m_data| m_data[:model_name] }
    end

    def model
      self.class.models.keys.detect { |m| self.class.models[m][:model_name] == record_model }
    end

    def record
      relations.keys.each do |r|
        if (value = send(r))
          return value
        end
      end
      nil
    end

    def version_enum
      (record && record.version && (1..record.version).to_a.reverse) || []
    end

    def ready_to_save?
      record.present?
    end

    def can_be_restarted?
      ready_to_save?
    end

    def to_s
      "#{record_model} #{record.try(:custom_title) || record.to_s} v#{version}"
    end

    class << self

      def where(expression)
        if expression.is_a?(Hash) &&
          (model = expression.delete(:model) || expression.delete('model')) &&
          (m_data = models[model]) &&
          (record_key = expression.keys.detect { |key| key.to_s == 'record_id' })
          record_id = "#{m_data[:property]}_id".to_sym
          if record_key.is_a?(Origin::Key)
            value = expression.delete(record_key)
            record_key.instance_variable_set(:@name, record_id)
            expression[record_key] = value
          else
            expression[record_id] = expression.delete(record_key)
          end
        end
        super
      end

      def for(object)
        if (m_data = models[object.class])
          where("#{m_data[:property]}_id" => object.id).first
        else
          nil
        end
      end

    end
    
  end
end
