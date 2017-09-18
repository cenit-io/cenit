module RailsAdmin
  module Config
    module Fields
      module Types
        class SortReverseString < RailsAdmin::Config::Fields::Types::String

          register_instance_option :sort_reverse? do
            true
          end
        end
      end
    end
  end
end