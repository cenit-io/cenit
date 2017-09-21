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

        register_instance_option :index_pretty_value do
          pretty_value
        end

        register_instance_option :filter_type do
          type
        end
      end
    end
  end
end
