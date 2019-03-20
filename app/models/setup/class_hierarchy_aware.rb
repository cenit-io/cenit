module Setup
module ClassHierarchyAware
    extend ActiveSupport::Concern

    included do
      before_save :check_instance_type
    end

    def check_instance_type
      if self.class.abstract?
        errors.add(:base, "Saving #{self.class} record is only allowed for subclasses #{self.class.class_hierarchy.select { |c| !c.abstract? }.to_sentence}")
        false
      else
        true
      end
    end

    module ClassMethods
      def class_hierarchy
        ([self] + descendants.collect(&:class_hierarchy)).flatten.uniq
      end

      def concrete_class_hierarchy
        class_hierarchy.select(&:concrete?)
      end

      def abstract_class(*args)
        @abstract_class = args[0].present? if args.length.positive?
        @abstract_class
      end

      def abstract?
        abstract_class.present?
      end

      def concrete?
        !abstract?
      end
    end
  end
end
