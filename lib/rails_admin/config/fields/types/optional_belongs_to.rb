module RailsAdmin
  module Config
    module Fields
      module Types
        class OptionalBelongsTo < RailsAdmin::Config::Fields::Types::BelongsToAssociation

          def with(bindings)
            if (obj = bindings[:object])
              selected =
                (controller = bindings[:controller]) &&
                (params = controller.params) &&
                !params.has_key?(:_restart) &&
                (params = params[controller.abstract_model.param_key]) &&
                params.has_key?(foreign_key)
              obj.define_singleton_method(:"#{name}_selected?") do
                selected
              end
              obj.define_singleton_method(:"selecting_#{name}?") do
                !selected
              end
            end
            super
          end

          register_instance_option :partial do
            if (obj = bindings[:object]).send("selecting_#{name}?") ||
               (required? && value.blank?) ||
               obj.errors[name].present?
              :form_filtering_select
            else
              :selected_field
            end
          end

          register_instance_option :help do
            if required?
              I18n.t('admin.form.required')
            elsif bindings[:object].send("selecting_#{name}?")
              I18n.t('admin.form.optional')
            else
              nil
            end
          end

        end
      end
    end
  end
end