module Cancelable
  extend ActiveSupport::Concern

  def cancel
    fail NotImplementedError
  end

  def cancelled?
    fail NotImplementedError
  end

  module ClassMethods

    def cancel_all(scope = all)
      scope.each(&:cancel)
    end
  end
end