module RailsAdmin
  module Config
    module Actions
      class TraceIndex < RailsAdmin::Config::Actions::Base

        register_instance_option :enabled? do
          bindings[:abstract_model].nil? || bindings[:abstract_model].is_a?(RailsAdmin::MongoffAbstractModel) || (
          (only.nil? || [only].flatten.collect(&:to_s).include?(bindings[:abstract_model].to_s)) &&
            ![except].flatten.collect(&:to_s).include?(bindings[:abstract_model].to_s) &&
            !bindings[:abstract_model].config.excluded?
          )
        end

        register_instance_option :only do
          Mongoid::Tracer::Trace::TRACEABLE_MODELS
        end

        register_instance_option :authorization_key do
          :trace
        end

        register_instance_option :route_fragment do
          'trace'
        end

        register_instance_option :controller do
          proc do
            @tracer_model_config = @model_config
            @model_config = RailsAdmin::Config.model(Mongoid::Tracer::Trace)
            @context_abstract_model = @model_config.abstract_model

            if (data_type = @abstract_model.model.data_type).config.tracing_option_available? && !data_type.config.trace_on_default
              config_url = url_for(action: :data_type_config, model_name: RailsAdmin.config(Setup::DataType).abstract_model.to_param, id: data_type.id)
              flash[:warning] = "#{data_type.custom_title} tracing on default is not activated, <a href='#{config_url}'>#{t('admin.flash.click_here')}</a>.".html_safe
            end

            if (f = params[:f]) && (f = f[:target_id])
              target_id_field = @model_config._fields.detect { |field| field.name == :_id }
              f.each do |_, condition|
                if condition.is_a?(Hash)
                  condition.each do |op, values|
                    if op == 'v'
                      condition[op] = target_id_field.parse_value(values)
                    end
                  end
                end
              end
            end

            @objects = list_entries(@model_config, :trace, @action.trace_scope)
            render :index
          end
        end

        def trace_scope
          fail NotImplementedError
        end

        register_instance_option :link_icon do
          'fa fa-history'
        end

        register_instance_option :listing? do
          true
        end
      end
    end
  end
end