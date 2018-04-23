module Forms
  class ChildModelSelector
    include Mongoid::Document

    field :parent_model_name, type: String
    field :child_types, type: Array
    field :child_model_name, type: String

    validates_presence_of :child_model_name

    def ready_to_save?
      false
    end

    def parent_model
      @parent_model ||= parent_model_name.constantize
    end

    def children_models_names(ability)
      enum = {}
      (child_types || parent_model.descendants).collect do |child_model|
        child_model =
          begin
            child_model.constantize
          rescue
            Object
          end if child_model.is_a?(String)
        next unless child_model < parent_model
        next if child_model < Setup::ClassHierarchyAware && child_model.abstract_class
        model_config = RailsAdmin::Config.model(child_model)
        next unless model_config.child_visible? && ability.can?(:new, child_model)
        enum[model_config.label] = child_model.name
      end
      enum
    end

    rails_admin do
      visible false
      register_instance_option(:discard_submit_buttons) { true }
      edit do
        field :child_model_name, :enum do
          required true
          label do
            "#{RailsAdmin::Config.model(bindings[:object].parent_model).label} type"
          end
          enum do
            bindings[:object].children_models_names(bindings[:controller].current_ability)
          end
          register_instance_option :render do
            html = bindings[:view].render partial: "rails_admin/main/#{partial}", locals: { field: self, form: bindings[:form] }
            html += bindings[:view].text_field_tag(bindings[:form].dom_name(self).gsub(name.to_s, 'child_types'), (bindings[:object].child_types || []).to_json, type: 'hidden')
            html.html_safe
          end
        end
      end
    end

  end
end
