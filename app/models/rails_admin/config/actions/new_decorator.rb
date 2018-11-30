module RailsAdmin
  module Config
    module Actions
      New.class_eval do

        register_instance_option :http_methods do
          [:get, :post, :patch] # NEW / CREATE / COPY
        end

        register_instance_option :controller do
          proc do

            #Patch
            if request.get? || params[:_restart] # NEW

              if @model_config.asynchronous_persistence
                flash[:warning] = "When you save the operation will occurs asynchronous"
              end

              @object =
                if (token = Cenit::Token.where(token: params[:json_token]).first)
                  hash = JSON.parse(token.data) rescue {}
                  @abstract_model.model.data_type.new_from_json(hash)
                else
                  if (model = @abstract_model.model).is_a?(Class) &&
                    model < Setup::ClassHierarchyAware &&
                    (model.abstract_class || @model_config.hierarchy_selectable)
                    @model_config = RailsAdmin::Config.model(Forms::ChildModelSelector)
                    if (child_types = params[:types])
                      child_types = child_types.to_s.split(',')
                    end
                    @form_object = Forms::ChildModelSelector.new(parent_model_name: model.name, child_types: child_types)
                    if (children = @form_object.children_models_names(current_ability)).size == 1
                      @model_config = RailsAdmin::Config.model(children.values.first)
                      @abstract_model = @model_config.abstract_model
                      @form_object = nil
                      @abstract_model.new
                    else
                      @form_object
                    end
                  end
                  @abstract_model.new
                end
              @authorization_adapter && @authorization_adapter.attributes_for(:new, @abstract_model).each do |name, value|
                @object.send("#{name}=", value)
              end
              if (object_params = params[@abstract_model.to_param])
                @object.set_attributes(@object.attributes.merge(object_params))
              end
              respond_to do |format|
                format.html { render @form_object ? :form : @action.template_name }
                format.js { render @form_object ? :form : @action.template_name, layout: false }
              end

            elsif request.post? || request.patch? # CREATE / COPY

              # Patch
              if (model = @abstract_model.model).is_a?(Class) && model < Setup::ClassHierarchyAware
                selector_config = RailsAdmin::Config.model(Forms::ChildModelSelector)
                if (selector_attrs = params[selector_config.abstract_model.param_key]) && (child_model_name = selector_attrs[:child_model_name])
                  child_model =
                    begin
                      child_model_name.constantize
                    rescue
                      child_model_name = nil
                    end
                  if child_model_name
                    @model_config = RailsAdmin::Config.model(child_model)
                    @abstract_model = @model_config.abstract_model
                  else
                    @model_config = RailsAdmin::Config.model(Forms::ChildModelSelector)
                    if (child_types = selector_attrs[:child_types]).is_a?(String)
                      child_types =
                        begin
                          JSON.parse(child_types).to_a.flatten
                        rescue
                          nil
                        end
                    else
                      child_types = nil unless child_types.is_a?(Array)
                    end
                    @form_object = Forms::ChildModelSelector.new(parent_model_name: model.name, child_types: child_types)
                    @form_object.errors.add(:child_model_name, 'is not valid')
                  end
                end
              end

              if @form_object
                handle_save_error(:form)
              else
                @modified_assoc = []
                @object = @abstract_model.new
                sanitize_params_for!(request.xhr? ? :modal : :create)

                @object.set_attributes(params[@abstract_model.param_key])
                @authorization_adapter && @authorization_adapter.attributes_for(:create, @abstract_model).each do |name, value|
                  @object.send("#{name}=", value)
                end

                #Patch
                if (ok = params[:_next].nil?)
                  ok =
                    begin
                      if @model_config.asynchronous_persistence
                        do_flash_process_result ::Setup::AsynchronousPersistence.process(
                          model_name: @abstract_model.model_name,
                          attributes: @object.attributes
                        )
                        true
                      else
                        @object.save
                      end
                    rescue Exception => ex
                      @object.errors.add(:base, "Error while creating: #{ex.message}")
                      false
                    end
                end
                if ok
                  if (warnings = @object.try(:warnings)).present?
                    do_flash(:warning, 'Warning', warnings)
                  end
                  @auditing_adapter && @auditing_adapter.create_object(@object, @abstract_model, _current_user)
                  respond_to do |format|
                    format.html { redirect_to_on_success(skip_flash: @model_config.asynchronous_persistence) }
                    format.js { render json: { id: @object.id.to_s, label: @model_config.with(object: @object).object_label } }
                  end
                else
                  handle_save_error
                end
              end
            end
          end
        end
      end
    end
  end
end
