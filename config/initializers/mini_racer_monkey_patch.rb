require 'mini_racer'

module MiniRacer
  if Context.method_defined?(:eval_unsafe) || Context.private_method_defined?(:eval_unsafe)
    class Context
      def eval(str, options = nil)
        raise(ContextDisposedError, 'attempted to call eval on a disposed context!') if @disposed

        filename = options && options[:filename].to_s

        @eval_thread = Thread.current
        if options && options[:thread_safe]
          @current_exception = nil
          eval_unsafe(str, filename)
        else
          isolate_mutex.synchronize do
            @current_exception = nil
            eval_unsafe(str, filename)
          end
        end
      ensure
        @eval_thread = nil
        ensure_gc_thread if @ensure_gc_after_idle
      end
    end
  end
end
