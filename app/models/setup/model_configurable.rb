module Setup
  module ModelConfigurable
    extend ActiveSupport::Concern

    include ChangedIf

    included do
      after_destroy { config.destroy }

      changed_if { config.changed? }
    end

    def configure
      super
      config.save if config.changed?
    end

    module ClassMethods

      attr_reader :config_model, :foreign_key

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@config_model, @config_model)
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

        @foreign_key = relation.foreign_key.to_sym

        class_eval "def config
          @_config ||=
            begin
              if new_record?
                #{model}.new(#{relation.name}: self)
              else
                #{model}.find_or_create_by(#{relation.name}: self)
              end
            end
        end"

        delegate *config_model.config_fields.collect { |p| [p.to_sym, "#{p}=".to_sym] }.flatten, to: :config
      end

      def where(expression)
        if expression.is_a?(Hash) && config_model.config_fields.any? { |field| expression.has_key?(field.to_sym) || expression.has_key?(field) }
          config_options = {}
          config_model.config_fields.each do |field|
            if expression.has_key?(key = field.to_sym) || expression.has_key?(key = field)
              config_options[field] = expression.delete(key)
            end
          end
          super.any_in(id: config_model.where(config_options).collect { |config| config[foreign_key] })
        else
          super
        end
      end

      def clear_config_for(account, ids)
        super
        config_model.with(account).where(foreign_key.in => ids).delete_all
      end
    end
  end
end