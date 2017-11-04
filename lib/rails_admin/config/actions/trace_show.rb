module RailsAdmin
  module Config
    module Actions
      class TraceShow < RailsAdmin::Config::Actions::Base

        register_instance_option :authorization_key do
          :trace
        end

        register_instance_option :member do
          true
        end

        register_instance_option :route_fragment do
          'trace'
        end

        register_instance_option :controller do
          proc do
            redirect_to url_for(@action.url_options(action: @action.action_name, controller: 'rails_admin/main', model: @abstract_model.to_param, trace_id: @object.id))
          end
        end

        def url_options(opts)
          opts = super
          opts[:model_name] = bindings[:controller].instance_variable_get(:@abstract_model).to_param
          if (object = bindings[:object]).is_a?(Mongoid::Tracer::Trace)
            opts[:action] = :trace_index
            opts.delete(:id)
            opts[:trace_id] = object.id
          end
          opts
        end

        register_instance_option :i18n_key do
          if bindings[:object].is_a?(Mongoid::Tracer::Trace)
            :show
          else
            key
          end
        end

        register_instance_option :link_icon do
          if bindings[:object].is_a?(Mongoid::Tracer::Trace)
            'icon-info-sign'
          else
            'fa fa-code-fork'
          end
        end
      end
    end
  end
end