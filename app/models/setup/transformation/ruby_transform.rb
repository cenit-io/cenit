module Setup
  module Transformation
    class RubyTransform < Setup::Transformation::WithOptions

      attr_reader :targets

      def initialize(options)
        super
        @targets = []
        if target = options[:target]
          @targets << target
        end
      end

      def target
        @targets.empty? ? new_target : @targets.last
      end

      def get(record)
        raise Exception.new("Invalid target class #{record.orm_model}") unless record.is_a?(@target_model ||= target_data_type.records_model)
        @targets.pop
        @targets << record
      end

      def new_target
        method_missing(:new_target) if @options[:target]
        @targets << (@target_model ||= target_data_type.records_model).new
        @targets.last
      end

      class << self
        def run(options = {})
          context = new(options)
          result = context.send(:eval, options[:transformation])
          options[:targets] = context.targets
          result
        end

      end
    end
  end
end