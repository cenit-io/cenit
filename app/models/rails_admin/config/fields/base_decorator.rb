module RailsAdmin
  module Config
    module Fields
      class Base

        SHARED_READ_ONLY = Proc.new do
          read_only { (obj = bindings[:object]).creator_id != User.current.id && obj.shared? }
        end

        def shared_read_only
          instance_eval &SHARED_READ_ONLY
        end
      end
    end
  end
end
