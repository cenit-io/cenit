module RailsAdmin
  module Config
    module Fields
      module Types
        class EnumEdit < RailsAdmin::Config::Fields::Types::Enum

          register_instance_option :html_attributes do
            {
              required: required?,
              'data-enum_edit': true
            }
          end

          register_instance_option :filter_type do
            :enum
          end
        end
      end
    end
  end
end
