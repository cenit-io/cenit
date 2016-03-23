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
        end
        accepts_nested_attributes_for(*(relation_names + [allow_destroy: true]))
      end
    end
  end
end