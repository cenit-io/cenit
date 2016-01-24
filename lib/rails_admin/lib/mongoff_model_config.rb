module RailsAdmin

  class MongoffModelConfig < RailsAdmin::Config::Model

    def initialize(mongoff_entity)
      super(RailsAdmin::MongoffAbstractModel.abstract_model_for(mongoff_entity))
      @model = @abstract_model.model
      @parent = self

      (abstract_model.properties + abstract_model.associations).each do |property|
        type = property.type
        if property.is_a?(RailsAdmin::MongoffAssociation)
          type = (type.to_s + '_association').to_sym
        elsif enumeration = property.enum
          type = :enum
        end
        configure property.name, type do
          visible { property.visible? }
          label { property.name.to_s.to_title }
          filterable { property.filterable? }
          required { property.required? }
          valid_length { {} }
          enum { enumeration } if enumeration
          if title = property.title
            label { title }
          end
          if description = property.description
            description = (property.required? ? 'Required. ' : 'Optional. ') + description
            help { description }
          end
          if g = property.group
            group g.to_sym
          end
          if property.is_a?(RailsAdmin::MongoffAssociation)
            # associated_collection_cache_all true
            pretty_value do
              v = bindings[:view]
              [value].flatten.select(&:present?).collect do |associated|
                amc = polymorphic? ? RailsAdmin.config(associated) : associated_model_config # perf optimization for non-polymorphic associations
                am = amc.abstract_model
                wording = associated.send(amc.object_label_method)
                can_see = !am.embedded_in?(bindings[:controller].instance_variable_get(:@abstract_model)) && (show_action = v.action(:show, am, associated))
                can_see ? v.link_to(wording, v.url_for(action: show_action.action_name, model_name: am.to_param, id: associated.id), class: 'pjax') : wording
              end.to_sentence.html_safe
            end
          end
        end
      end

      navigation_label { target.data_type.navigation_label }

      object_label_method { @object_label_method ||= Config.label_methods.detect { |method| target.property?(method) } || :to_s }
    end

    def parent
      self
    end

    def target
      @model
    end

    def excluded?
      false
    end

    def label
      contextualized_label
    end

    def label_plural
      contextualized_label_plural
    end

    def contextualized_label(context = nil)
      if target.parent
        target.to_s.split('::').last
      else
        case context
        when nil
          target.data_type.title
        else
          target.data_type.custom_title
        end
      end
    end

    def contextualized_label_plural(context = nil)
      contextualized_label(context).pluralize
    end

    def root
      self
    end

    def visible?
      true
    end
  end
end