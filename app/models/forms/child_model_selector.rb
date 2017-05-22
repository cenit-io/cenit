module Forms
  class ChildModelSelector
    include Mongoid::Document

    field :parent_model_name, type: String
    field :child_model_name, type: String

    validates_presence_of :child_model_name

    def ready_to_save?
      false
    end

    def parent_model
      @parent_model ||= parent_model_name.constantize
    end

    def child_model_name_enum(ability)
      enum = {}
      parent_model.descendants.collect do |child_model|
        next if child_model < Setup::ClassHierarchyAware && child_model.abstract_class
        model_config = RailsAdmin::Config.model(child_model)
        next unless model_config.visible? && ability.can?(:new, child_model)
        enum[model_config.label] = child_model.name
      end
      enum
    end

    rails_admin do
      visible false
      register_instance_option(:discard_submit_buttons) { true }
      edit do
        field :child_model_name, :enum do
          label do
            "#{RailsAdmin::Config.model(bindings[:object].parent_model).label} type"
          end
          enum do
            bindings[:object].child_model_name_enum(bindings[:controller].current_ability)
          end
        end
      end
    end

  end
end
