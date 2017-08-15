module RailsAdmin
  module Config
    module Actions
      Dashboard.class_eval do
        register_instance_option :controller do
          proc do
            @history = @auditing_adapter && @auditing_adapter.latest || []
            @group_dashboard = params['group'] || nil
            if @action.statistics?
              #Patch
              @model_configs = {}
              @abstract_models =
                if current_user
                  (RailsAdmin::Config.visible_models(controller: self) + # TODO Include mongoff models configs only if needed
                    Setup::DataType.where(navigation_link: true).collect { |data_type| RailsAdmin.config(data_type.records_model).with(controller: self) }.select(&:visible)).collect(&:abstract_model).select do |absm|
                    ((model = absm.model) rescue nil) &&
                      (model.is_a?(Mongoff::Model) || model.include?(AccountScoped) || [Account].include?(model)) &&
                      (@model_configs[absm.model_name] = absm.config)
                  end
                else
                  Setup::Models.collect { |m| RailsAdmin::Config.model(m).with(controller: self) }.select(&:visible).collect do |config|
                    absm = config.abstract_model
                    @model_configs[absm.model_name] = config
                    absm
                  end
                end
              @most_recent_changes = {}
            end
            render @action.template_name, status: (flash[:error].present? ? :not_found : 200)
          end
        end

        register_instance_option :link_icon do
          'fa fa-dashboard'
        end
      end
    end
  end
end
