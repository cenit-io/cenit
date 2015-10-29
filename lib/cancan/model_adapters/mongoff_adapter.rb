module CanCan
  module ModelAdapters
    class MongoffAdapter < MongoidAdapter

      def self.for_class?(model_class)
        model_class.is_a?(Mongoff::Model)
      end

    end
  end
end

CanCan::ModelAdapters::AbstractAdapter.inherited(CanCan::ModelAdapters::MongoffAdapter)

Mongoff::Model.class_eval do
  include CanCan::ModelAdditions::ClassMethods
end