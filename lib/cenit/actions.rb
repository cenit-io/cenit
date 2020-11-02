module Cenit

  class Action

    attr_reader :key

    def only
      if @only
        [@only.call].flatten
      else
        []
      end
    end

    def except
      if @except
        [@except.call].flatten
      else
        []
      end
    end

    def initialize(key)
      @key = key
    end

    def only_for(&block)
      @only = block
    end

    def except_for(&block)
      @except = block
    end

    def enabled_for(model)
      (only.nil? || [only].flatten.collect(&:to_s).include?(model.to_s)) &&
        [except].flatten.collect(&:to_s).exclude?(model.to_s)
    end
  end

  module Actions

    class << self

      def store
        @actions ||= {}
      end

      def each(&block)
        store.values.each(&block) if block
      end

      def on(action, &block)
        unless (a = store[action])
          a = store[action] = Action.new(action)
        end
        a.instance_eval(&block) if block
      end
    end
  end
end
