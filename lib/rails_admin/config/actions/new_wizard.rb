module RailsAdmin
  module Config
    module Actions
      class NewWizard < RailsAdmin::Config::Actions::New

        register_instance_option :controller do

          proc do

            puts params

            if request.get? || params[:_restart] # NEW

              @object = @abstract_model.new
              @authorization_adapter && @authorization_adapter.attributes_for(:new, @abstract_model).each do |name, value|
                @object.send("#{name}=", value)
              end
              if object_params = params[@abstract_model.to_param]
                @object.set_attributes(@object.attributes.merge(object_params))
              end
              respond_to do |format|
                format.html { render @action.template_name }
                format.js { render @action.template_name, layout: false }
              end

            elsif request.post? # CREATE

              @modified_assoc = []
              @object = @abstract_model.new
              NewWizard.sanitize_params_for!(request.xhr? ? :modal : :create, @model_config, params[@abstract_model.param_key], view_context)

              @object.set_attributes(params[@abstract_model.param_key])
              @authorization_adapter && @authorization_adapter.attributes_for(:create, @abstract_model).each do |name, value|
                @object.send("#{name}=", value)
              end

              if (!@object.respond_to?(:ready_to_save?) || @object.ready_to_save?) && params[:_save] && @object.save
                @auditing_adapter && @auditing_adapter.create_object(@object, @abstract_model, _current_user)
                respond_to do |format|
                  format.html { redirect_to_on_success }
                  format.js { render json: {id: @object.id.to_s, label: @model_config.with(object: @object).object_label} }
                end
              else
                unless @object.errors.blank?
                  flash.now[:error] = t('admin.flash.error', name: @model_config.label, action: t("admin.actions.#{@action.key}.done").html_safe).html_safe
                  flash.now[:error] += %(<br>- #{@object.errors.full_messages.join('<br>- ')}).html_safe
                end

                respond_to do |format|
                  format.html { render :new_wizard, status: :not_acceptable }
                  format.js { render :new_wizard, layout: false, status: :not_acceptable }
                end
              end

            end
          end
        end

        register_instance_option :link_icon do
          'icon-plus'
        end


        def self.sanitize_params_for!(action, model_config, target_params, view_context)
          return unless target_params.present?
          fields = model_config.send(action).with(controller: self, view: view_context, object: @object).fields
          allowed_methods = fields.collect(&:allowed_methods).flatten.uniq.collect(&:to_s) << 'id' << '_destroy'
          fields.each { |f| f.parse_input(target_params) }
          target_params.slice!(*allowed_methods)
          target_params.permit! if target_params.respond_to?(:permit!)
          fields.select(&:nested_form).each do |association|
            children_params = association.multiple? ? target_params[association.method_name].try(:values) : [target_params[association.method_name]].compact
            (children_params || []).each do |children_param|
              sanitize_params_for!(:nested, association.associated_model_config, children_param, view_context)
            end
          end
        end
      end
    end
  end
end
