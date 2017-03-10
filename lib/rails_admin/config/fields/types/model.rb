module RailsAdmin
  module Config
    module Fields
      module Types
        class Model < RailsAdmin::Config::Fields::Types::Text

          register_instance_option :visible_parent_lookup do
            false
          end

          register_instance_option :pretty_value do
            if (model = value)
              looking_up = true
              wording = ''
              while looking_up
                v = bindings[:view]
                looking_up =
                  if (amc = RailsAdmin::Config.registry[model.to_s.to_sym])
                    am = amc.abstract_model
                    wording = amc.navigation_label + ' > ' + amc.label
                    if !am.embedded? && (index_action = v.action(:index, am))
                      wording = v.link_to(amc.label, v.url_for(action: index_action.action_name, model_name: am.to_param), class: 'pjax')
                      false
                    else
                      model = model.superclass
                      visible_parent_lookup
                    end
                  else
                    model = model.superclass
                  end
              end
              wording.html_safe
            end
          end
        end
      end
    end
  end
end
