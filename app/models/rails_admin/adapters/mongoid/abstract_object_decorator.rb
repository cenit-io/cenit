# rails_admin-1.0 ready
require 'rails_admin/adapters/active_record/abstract_object'
module RailsAdmin
  module Adapters
    module Mongoid
      AbstractObject.class_eval do

        def send(*args, &block)
          #Mongoff records always response
          if object.is_a?(Mongoff::Record)
            object.send(*args, &block)
          else
            super
          end
        end
      end
    end
  end
end
