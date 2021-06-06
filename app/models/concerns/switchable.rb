module Switchable
  extend ActiveSupport::Concern

  def switch
    fail NotImplementedError
  end

  module ClassMethods

    def switch_all(scope = all)
      scope.each(&:switch)
    end
  end
end