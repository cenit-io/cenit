module RailsAdmin
  module Config
    module Fields
      module Types
        class Record < RailsAdmin::Config::Fields::Types::Text

          register_instance_option :pretty_value do
            if value
              v = bindings[:view]
              amc = RailsAdmin.config(value.class)
              am = amc.abstract_model
              wording = value.send(amc.object_label_method)
              can_see = !am.embedded? && (show_action = v.action(:show, am, value))
              (can_see ? v.link_to(wording, v.url_for(action: show_action.action_name, model_name: am.to_param, id: value.id), class: 'pjax') : wording).html_safe
            end
          end

        end
      end
    end
  end
end
