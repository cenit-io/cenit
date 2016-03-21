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

        end
      end
    end
  end
end
