module RailsAdmin
  module Config
    module Actions
      Dashboard.class_eval do
        register_instance_option :controller do
          proc do
            @dashboard_models = []
            @dashboard_group_ref = params['group'] || nil
            @dashboard_group = dashboard_group(@dashboard_group_ref)
            if @action.statistics?
              #Patch
              @model_configs = {}
              @abstract_models =
                if current_user
                  (RailsAdmin::Config.visible_models(controller: self) +
                    (show_mongoff_navigation? ? Setup::DataType.where(navigation_link: true) : []).collect { |data_type| RailsAdmin.config(data_type.records_model).with(controller: self) }.select(&:visible) +
                    (show_ecommerce_navigation? ? ecommerce_data_types : []).collect { |data_type| RailsAdmin.config(data_type.records_model).with(controller: self) }).collect(&:abstract_model).select do |absm|
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
