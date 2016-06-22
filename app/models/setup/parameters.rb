module Setup
  module Parameters
    extend ActiveSupport::Concern

    included do
      after_save :configure
    end

    def configure
      super
      reflect_on_all_associations(:embeds_many).each do |relation|
        next unless relation.klass == Setup::Parameter
        names = []
        send(relation.name).each do |parameter|
          parameter.configure
          names << parameter.name
        end
        Setup::ParameterConfig.where("#{relation.inverse}_id" => id,
                                     location: relation.name,
                                     :name.nin => names).delete_all
      end
    end

    module ClassMethods

      def parameters(*relation_names)
        relation_names = relation_names.collect(&:to_s)
        inverse_name = to_s.split('::').last.underscore
        relation_names.each do |relation_name|
          embeds_many relation_name, class_name: Setup::Parameter.to_s, inverse_of: inverse_name
          Setup::Parameter.embedded_in inverse_name, class_name: to_s, inverse_of: relation_name
          unless Setup::ParameterConfig.reflect_on_association(inverse_name)
            Setup::ParameterConfig.belongs_to inverse_name, class_name: to_s, inverse_of: nil
            Setup::ParameterConfig.attr_readonly inverse_name
            Setup::ParameterConfig.build_in_data_type.including(inverse_name)
          end
        end
        after_destroy do
          Setup::ParameterConfig.where("#{inverse_name}_id" => id).delete_all
        end
        accepts_nested_attributes_for *relation_names, allow_destroy: true
      end
    end
  end
end