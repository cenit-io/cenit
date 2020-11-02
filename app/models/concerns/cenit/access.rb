module Cenit
  module Access
    extend ActiveSupport::Concern

    DEFAULT = [:create, :read, :update, :destroy]

    class_methods do

      def allow(*actions)
        @allowed_actions = Set.new(actions.flatten.map(&:to_sym))
      end

      def allowed_actions
        @allowed_actions || []
      end

      def deny(*actions)
        @denied_actions = Set.new(actions.flatten.map(&:to_sym))
      end

      def denied_actions
        @denied_actions || []
      end

      def can?(action)
        !(@allowed_actions || @denied_actions) ||
          (@allowed_actions && @allowed_actions.include?(action)) ||
          (@denied_actions && @denied_actions.exclude?(:all) && @denied_actions.exclude?(action)) ||
          (superclass < Access && superclass.can?(action))
      end
    end
  end
end