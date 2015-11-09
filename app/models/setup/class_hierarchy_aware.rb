module Setup
  module ClassHierarchyAware
    extend ActiveSupport::Concern

    module ClassMethods

      def class_hierarchy
        ([self] + descendants.collect(&:class_hierarchy)).flatten.uniq
      end
    end
  end
end