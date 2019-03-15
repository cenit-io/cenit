module RailsAdmin
  module Config
    module Actions

      class Compare < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Mongoid::Tracer::Trace::TRACEABLE_MODELS
        end

        register_instance_option :http_methods do
          [:get, :post, :patch]
        end

        register_instance_option :collection do
          true
        end

        register_instance_option :controller do
          proc do
            model = @abstract_model.model
            @touched = false

            @base_id =
              if (base_record = model.where(id: params[:base_id]).first)
                @touched = true
                @base_label = base_record.send(@model_config.object_label_method)
                params[:base_id]
              else
                nil
              end

            @fork_id =
              if (fork_record = model.where(id: params[:fork_id]).first)
                @touched = true
                @fork_label = fork_record.send(@model_config.object_label_method)
                params[:fork_id]
              else
                nil
              end

            @properties = (model.simple_properties_schemas.keys.to_a + model.trace_include - model.trace_ignore - %w(_id id)).uniq

            if (comp_props = params[:properties])
              @touched = true
              if comp_props.is_a?(Array)
                comp_props = comp_props.map(&:to_s)
              else
                comp_props = []
              end
              comp_props.keep_if { |prop| @properties.include?(prop) }
            end
            @comparing_properties = comp_props || []

            if base_record && fork_record && @comparing_properties.present?
              hash = fork_record.to_hash(viewport: "{#{@comparing_properties.join(' ')}}")
              hash.delete('_primary')

              @can_merge = current_ability.can?(:edit, base_record)

              if params[:_merge] && @can_merge
                base_record.fill_from(hash)
                if base_record.save
                  redirect_to rails_admin.show_path(model_name: @abstract_model.to_param, id: @base_id)
                else
                  @object = base_record
                  handle_save_error
                end
              else
                mirror_record = @abstract_model.model.new(base_record.attributes.reject { |_, v| v.nil? })
                base_trace = ::Mongoid::Tracer::Trace.new(mirror_record.trace_action_attributes(:create))
                base_record.fill_from(hash)
                trace = ::Mongoid::Tracer::Trace.new(base_record.trace_action_attributes(:update))
                @diff = build_diff(@abstract_model, trace.changes_set(base_trace))
                unless (@diff[:additions] + @diff[:deletions]).positive?
                  @can_merge = @diff = nil
                end
              end
            end
          end
        end

        register_instance_option :link_icon do
          'fa fa-code-fork'
        end
      end
    end
  end
end