module RailsAdmin
  module Config
    module Fields
      module Types
        class Model < RailsAdmin::Config::Fields::Types::Text

          register_instance_option :pretty_value do
            if value
              v = bindings[:view]
              amc = RailsAdmin.config(value)
              am = amc.abstract_model
              wording = amc.navigation_label + ' > ' + amc.label
              can_see = !am.embedded? && (index_action = v.action(:index, am))
              (can_see ? v.link_to(amc.label, v.url_for(action: index_action.action_name, model_name: am.to_param), class: 'pjax') : wording).html_safe
            end
          end

        end
      end
    end
  end
end
