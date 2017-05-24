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

              @object =
                if (token = Cenit::Token.where(token: params[:json_token]).first)
                  hash = JSON.parse(token.data) rescue {}
                  @abstract_model.model.data_type.new_from_json(hash)
                else
                  if (model = @abstract_model.model) < Setup::ClassHierarchyAware && model.abstract_class
                    @model_config = RailsAdmin::Config.model(Forms::ChildModelSelector)
                    @form_object = Forms::ChildModelSelector.new(parent_model_name: model.name)
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

              if (model = @abstract_model.model) < Setup::ClassHierarchyAware && model.abstract_class
                selector_config = RailsAdmin::Config.model(Forms::ChildModelSelector)
                if (selector_attrs = params[selector_config.abstract_model.param_key]) && (child_model_name = selector_attrs[:child_model_name])
                  child_model =
                    begin
                      child_model_name.constantize
                    rescue
                      nil
                    end
                  if child_model_name
                    @model_config = RailsAdmin::Config.model(child_model)
                    @abstract_model = @model_config.abstract_model
                  end
                end
              end

              @modified_assoc = []
              @object = @abstract_model.new
              sanitize_params_for!(request.xhr? ? :modal : :create)

              @object.set_attributes(params[@abstract_model.param_key])
              @authorization_adapter && @authorization_adapter.attributes_for(:create, @abstract_model).each do |name, value|
                @object.send("#{name}=", value)
              end

              #Patch
              if params[:_next].nil? && @object.save
                @auditing_adapter && @auditing_adapter.create_object(@object, @abstract_model, _current_user)
                respond_to do |format|
                  format.html { redirect_to_on_success }
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
