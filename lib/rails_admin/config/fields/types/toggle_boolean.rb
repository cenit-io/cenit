module RailsAdmin
  module Config
    module Fields
      module Types
        class ToggleBoolean < RailsAdmin::Config::Fields::Types::Boolean

          register_instance_option :pretty_value do
            if (api_path = @abstract_model.api_path)
              %(<span class='toggle-boolean' data-url='#{Cenit.homepage}/api/v2/#{api_path}/#{bindings[:object].id}' data-field='#{name}' data-value='#{value}'></span>)
            else
              case value
              when nil
                %(<span class='label label-default'>&#x2012;</span>)
              when false
                %(<span class='label label-danger'>&#x2718;</span>)
              when true
                %(<span class='label label-success'>&#x2713;</span>)
              end
            end.html_safe
          end
        end
      end
    end
  end
end
