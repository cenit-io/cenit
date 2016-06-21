module Setup
  module Parameters
    extend ActiveSupport::Concern

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
        after_save do
          relation_names.each do |relation_name|
            names = []
            send(relation_name).each do |parameter|
              parameter.configure
              names << parameter.name
            end
            Setup::ParameterConfig.where("#{inverse_name}_id" => id,
                                         location: relation_name,
                                         :name.nin => names).delete_all
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