require 'mini_racer'

module MiniRacer

  class Context
    def eval(str, options = nil)
      raise(ContextDisposedError, 'attempted to call eval on a disposed context!') if @disposed

      filename = options && options[:filename].to_s

      @eval_thread = Thread.current
      if options && options[:thread_safe]
        @current_exception = nil
        timeout do
          eval_unsafe(str, filename)
        end
      else
        isolate_mutex.synchronize do
          @current_exception = nil
          timeout do
            eval_unsafe(str, filename)
          end
        end
      end
    ensure
      @eval_thread = nil
      ensure_gc_thread if @ensure_gc_after_idle
    end
  end
end