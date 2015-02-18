module Setup
  module Transformation
    class RenitTransform < Setup::Transformation::AbstractTransform

      attr_reader :targets

      def initialize(options)
        puts options
        @options = options
        @targets = []
        if target = options[:target]
          @targets << target
        end
      end

      def method_missing(symbol, *args)
        if args.length == 0 && value = @options[symbol]
          value
        else
          super
        end
      end

      def respond_to?(symbol)
        @options[symbol] || super
      end

      def source
        respond_to?(:sources) ? sources.current : method_missing(:source)
      end

      def next_source
        sources.next
      end

      def target
        @targets.empty? ? new_target : @targets.last
      end

      def get(record)
        raise Exception.new("Invalid target class #{record.class}") unless record.is_a?(@target_model ||= target_data_type.model)
        @targets.pop
        @targets << record
      end

      def new_target
        method_missing(:new_target) if @options[:target]
        @targets << (@target_model ||= target_data_type.model).new
        @targets.last
      end

      class << self
        def run(options = {})
          context = RenitTransform.new(options)
          result = context.send(:eval, options[:transformation])
          options[:targets] = context.targets
          result
        end

        def types
          [:Import, :Export, :Update, :Conversion]
        end
      end
    end
  end
end