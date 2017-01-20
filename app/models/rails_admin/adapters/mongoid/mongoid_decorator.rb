module RailsAdmin
  module Adapters
    module Mongoid
      AbstractObject.module_eval do

        def send(*args, &block)
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
