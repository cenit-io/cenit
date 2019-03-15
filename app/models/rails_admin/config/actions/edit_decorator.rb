module RailsAdmin
  module Config
    module Actions
      Edit.class_eval do
        def self.loading_member
          Thread.current[:cenit_pins_off] = true
          yield
        ensure
          Thread.current[:cenit_pins_off] = nil
        end


        register_instance_option :controller do
          proc do
            if request.get? # EDIT

              if @model_config.asynchronous_persistence
                flash[:warning] = "When you save the operation will occurs asynchronous"
              end

              respond_to do |format|
                format.html { render @action.template_name }
                format.js { render @action.template_name, layout: false }
              end

            elsif request.put? # UPDATE
              sanitize_params_for!(action = (request.xhr? ? :modal : :update))

              @object.set_attributes(form_attributes = params[@abstract_model.param_key])

              #Patch
              if (synchronized_fields = @model_config.with(object: @object).try(:form_synchronized))
                params_to_check = {}
                model_config.send(action).with(controller: self, view: view_context, object: @object).fields.each do |field|
                  if synchronized_fields.include?(field.name.to_sym)
                    params_to_check[field.name.to_sym] = (field.is_a?(RailsAdmin::Config::Fields::Association) ? field.method_name : field.name).to_s
                  end
                end
                params_to_check.each do |field, param|
                  @object.send("#{field}=", nil) unless form_attributes[param].present?
                end
              end

              @authorization_adapter && @authorization_adapter.attributes_for(:update, @abstract_model).each do |name, value|
                @object.send("#{name}=", value)
              end
              changes = @object.changes
              #Patch
              save_options = {}
              if (model = @abstract_model.model).is_a?(Class) && model < FieldsInspection
                save_options[:inspect_fields] = Account.current.nil? || !::User.current_super_admin?
              end
              ok =
                begin
                  if @model_config.asynchronous_persistence
                    do_flash_process_result ::Setup::AsynchronousPersistence.process(
                      model_name: @abstract_model.model_name,
                      id: @object.id,
                      attributes: @object.attributes,
                      options: save_options
                    )
                    true
                  else
                    @object.save(save_options)
                  end
                rescue Exception => ex
                  @object.errors.add(:base, "Error while updating: #{ex.message}")
                  false
                end
              if ok
                if (warnings = @object.try(:warnings)).present?
                  do_flash(:warning, 'Warning', warnings)
                end
                @auditing_adapter && @auditing_adapter.update_object(@object, @abstract_model, _current_user, changes)
                respond_to do |format|
                  format.html { redirect_to_on_success(skip_flash: @model_config.asynchronous_persistence) }
                  format.js { render json: { id: @object.id.to_s, label: @model_config.with(object: @object).object_label } }
                end
              else
                handle_save_error :edit
              end

            end
          end
        end
      end
    end
  end
end
