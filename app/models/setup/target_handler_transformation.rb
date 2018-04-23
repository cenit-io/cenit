module Setup
  module TargetHandlerTransformation

    def after_execute(options)
      super
      return unless (target = options[:target])
      if !options.key?(:save_result) || options[:save_result]
        target.instance_variable_set(:@discard_event_lookup, options[:discard_events])
        unless Cenit::Utility.save(target)
          fail PersistenceException.new(target)
        end
      end
      options[:result] = target
    end
  end
end
