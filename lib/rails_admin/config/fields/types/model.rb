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
                  if (model_config = RailsAdmin::Config.registry[model.to_s.to_sym]) ||
                     (model_config = Config.model(model)).is_a?(RailsAdmin::MongoffModelConfig)
                    am = model_config.abstract_model
                    wording = model_config.navigation_label + ' > ' + model_config.label
                    if !am.embedded? && (index_action = v.action(:index, am))
                      wording = v.link_to(model_config.label, v.url_for(action: index_action.action_name, model_name: am.to_param), class: 'pjax')
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
