module Setup
  module ModelConfigurable
    extend ActiveSupport::Concern

    include ChangedIf

    included do
      after_destroy { config.destroy }

      changed_if { config.changed? }
    end

    def warnings
      @warnings ||= []
    end

    def configure
      super
      if config.changed?
        warnings.clear
        config.save
        config.errors.full_messages.each { |warn| warnings << warn }
      end
    end

    def config
      @_config ||=
        begin
          if new_record?
            self.class.config_model.new(self.class.relation_name => self)
          else
            self.class.config_model.find_or_initialize_by(self.class.relation_name => self)
          end
        end
    end

    module ClassMethods

      attr_reader :config_model, :relation_name, :foreign_key

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@config_model, @config_model)
        subclass.instance_variable_set(:@relation_name, @relation_name)
        subclass.instance_variable_set(:@foreign_key, @foreign_key)
      end

      def config_with(model, options = {})
        @config_model = model
        config_fields = options[:only] || model.config_fields
        config_fields = [config_fields] unless config_fields.is_a?(Enumerable)
        config_fields = config_fields.to_a

        shared_configurable *config_fields

        relation = model.reflect_on_all_associations(:belongs_to).detect { |r| r.klass == self && r.inverse_of.nil? }

        fail "Belongs-To association config not found between #{model} and #{self}" unless relation
        fail "Belongs-To association config #{model}.#{relation.name} is autosave (it should not)" if relation.autosave

        @relation_name = relation.name
        @foreign_key = relation.foreign_key.to_sym

        delegate *config_model.config_fields.collect { |p| [p.to_sym, "#{p}=".to_sym] }.flatten, to: :config
      end

      def where(expression)
        config_criteria = nil
        if expression.is_a?(Hash)
          nil_configs = false
          config_options = {}
          config_model.config_fields.each do |field|
            if expression.key?(key = field.to_s) || expression.key?(key = field.to_sym)
              nil_configs ||= nil_option?(config_options[field] = expression.delete(key))
            end
          end
          if config_options.present?
            config_criteria = { :id.in => config_model.where(config_options).collect { |config| config[foreign_key] } }
            if nil_configs
              config_criteria = { '$or' => [config_criteria, { :id.nin => config_model.all.collect(&:"#{foreign_key}") }] }
            end
          end
        end
        q = super
        if config_criteria
          q = q.and(config_criteria)
        end
        q
      end

      def nil_option?(option)
        case option
        when nil
          true
        when Array
          option.any?(&:nil?)
        when Hash
          %w($in $or).any? { |op| (values = option[op] || option[op.to_sym]).is_a?(Array) && nil_option?(values) }
        else
          false
        end
      end

      def clear_config_for(tenant, ids)
        super
        config_model.with(tenant).where(foreign_key.in => ids).delete_all
      end

    end
  end
end
