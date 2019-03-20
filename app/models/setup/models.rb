module Setup
  class Models
    class << self
      include Enumerable

      def unregist(model)
        instance_values.values.each { |hash| hash.delete(model) }
      end

      def regist(model)
        excluded_actions_for(model)
      end

      def registered?(model)
        instance_values.values.each { |hash| return true if hash.has_key?(model) }
        false
      end

      def all
        set = Set.new
        instance_values.values.each { |hash| set.merge(hash.keys) }
        set
      end

      def each(&block)
        all.each(&block)
      end

      def method_missing(symbol, *args)
        if (name = symbol.to_s).end_with?('_actions_for')
          name = name.to(name.length - '_actions_for'.length - 1)
          instance_eval <<-RUBY
          def #{name}_actions
            @#{name}_actions ||= Hash.new { |h, k| h[k] = [] }
          end
          def #{symbol}(model, *actions)
            #{name}_actions[model] += actions.flatten
          end
          def each_#{name}_action(&block)
            #{name}_actions.each(&block)
          end
          RUBY
          send(symbol, *args)
        else
          super
        end
      end

    end

  end
end
