module ThreadAware
  extend ActiveSupport::Concern

  def thread_key
    self.class.thread_key
  end

  module ClassMethods
    def thread_key
      "[cenit]#{to_s}"
    end
  end

end