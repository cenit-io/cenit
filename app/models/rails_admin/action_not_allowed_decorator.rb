# rails_admin-1.0 ready
module RailsAdmin
  ActionNotAllowed.class_eval do
    def initialize(msg = 'Action not allowed')
      super
    end
  end
end
