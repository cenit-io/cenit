module RailsAdmin
  module Config
    module Actions
      class TraceShow < RailsAdmin::Config::Actions::Base

        register_instance_option :enabled? do
          (am = bindings[:abstract_model]).nil? || (
          am.is_a?(RailsAdmin::MongoffAbstractModel) && !am.model.is_a?(Mongoff::GridFs::FileModel)) || (
          (only.nil? || [only].flatten.collect(&:to_s).include?(bindings[:abstract_model].to_s)) &&
            ![except].flatten.collect(&:to_s).include?(bindings[:abstract_model].to_s) &&
            !bindings[:abstract_model].config.excluded?
          )
        end

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
            url_opts = {
              action: :trace_index,
              controller: 'rails_admin/main',
              model: @abstract_model.to_param
            }
            if @object.is_a?(Mongoid::Tracer::Trace)
              url_opts[:trace_id] = @object.id
            else
              url_opts[:f] = { target_id: { a: { v: @object.id.to_s } } }
            end
            redirect_to url_for(url_opts)
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