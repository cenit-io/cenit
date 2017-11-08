module RailsAdmin
  module OverrideActionsHelper

    def self.included(base)
      RailsAdmin::Config::Actions.all.each do |action|
        base.class_eval <<-EOS, __FILE__, __LINE__ + 1
        def #{action.action_name}
          action = RailsAdmin::Config::Actions.find('#{action.action_name}'.to_sym)
          @authorization_adapter.try(:authorize, action.authorization_key, @abstract_model, @object)
          @action = action.with({controller: self, abstract_model: @abstract_model, object: @object})
          fail(ActionNotAllowed) unless @action.enabled?
          @page_name = wording_for(:title)

          if @abstract_model
            @context_abstract_model = @abstract_model
            custom_action = "#{action.action_name}_\#{@abstract_model.model_name.parameterize.underscore}".to_sym
            return send(custom_action) if respond_to?(custom_action)
          end

          instance_eval &@action.controller
        end
        EOS
      end
    end

  end
end

