module Setup
  module Parameters
    extend ActiveSupport::Concern

    include ChangedIf

    included do
      after_save :configure
    end

    def configure
      super if self.class.include?(Setup::SharedConfigurable)

      reflect_on_all_associations(:has_many).each do |relation|
        next unless relation.klass == Setup::Parameter
        keys = []
        send(relation.name).each do |parameter|
          parameter.save
          keys << parameter.key
        end
        Setup::Parameter.where(relation.inverse.foreign_key => id, :key.nin => keys).delete_all
      end
    end

    module ClassMethods
      def parameters_relations_names
        @parameters_relations_names || (superclass < Parameters && superclass.parameters_relations_names) || []
      end

      def parameters(*relation_names)
        relation_names = relation_names.collect(&:to_s)
        @parameters_relations_names = [parameters_relations_names, relation_names].flatten.compact
        relation_names.each do |relation_name|
          inverse_name = "#{relation_name}_#{to_s.split('::').last.underscore}"
          has_many relation_name, class_name: Setup::Parameter.to_s, inverse_of: inverse_name, dependent: :destroy
          Setup::Parameter.belongs_to inverse_name, class_name: to_s, inverse_of: relation_name
          Setup::Parameter.attr_readonly inverse_name
          Setup::Parameter.trace_ignore "#{inverse_name}_id"
        end
        build_in_data_type.embedding(*relation_names)
        build_in_data_type.exclusive_referencing(*relation_names)
        accepts_nested_attributes_for *relation_names, allow_destroy: true
        shared_configurable *relation_names if include?(Setup::SharedConfigurable)
        before_save do
          self.class.parameters_relations_names.each do |relation_name|
            send(relation_name).group_by { |p| p.key }.each do |key, parameters|
              if parameters.size > 1
                errors.add(relation_name, "have multiple definitions with the same name: #{key}")
              end
            end
          end
          abort_if_has_errors
        end
        changed_if do
          self.class.parameters_relations_names.any? do |relation_name|
            send(relation_name).any? { |p| p.changed? }
          end
        end
      end
    end
  end
end
