module Setup
  class Models
    class << self
      include Enumerable

      def unregist(model)
        excluded_actions.delete(model)
        included_actions.delete(model)
      end

      def regist(model)
        excluded_actions[model]
      end

      def each_excluded_action(&block)
        excluded_actions.each(&block)
      end

      def exclude_actions_for(model, *actions)
        excluded_actions[model] += actions
      end

      def excluded_actions_for(model)
        excluded_actions[model]
      end

      def registered?(model)
        excluded_actions.include?(model)
      end

      def each_included_action(&block)
        included_actions.each(&block)
      end

      def include_actions_for(model, *actions)
        included_actions[model] += actions
      end

      def included_actions_for(model)
        included_actions[model]
      end

      private

      def excluded_actions
        @excluded_actions ||= Hash.new { |h, k| h[k] = [] }
      end

      def included_actions
        @included_actions ||= Hash.new { |h, k| h[k] = [] }
      end
    end
  end
end
