module RailsAdmin
  module Config
    module Fields
      module Types
        class Url < RailsAdmin::Config::Fields::Types::Text

          register_instance_option :pretty_value do
            bindings[:view].link_to(value, value, target: '_blank').html_safe if value
          end

        end
      end
    end
  end
end
