module ThreadAware
  extend ActiveSupport::Concern

  def current_thread_cache
    self.class.current_thread_cache
  end

  module ClassMethods
    def thread_key
      "[cenit]#{to_s}"
    end

    def current_thread_cache(key = thread_key)
      unless (value = Thread.current[key])
        value = default_thread_value
        Thread.current[key] = value
      end
      value
    end

    def default_thread_value
      {}
    end
  end
end