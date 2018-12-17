module RailsAdmin
  module Models
    module Mongoid
      module Tracer
        module TraceAdmin
          extend ActiveSupport::Concern

          included do
            rails_admin do
              navigation_label 'Monitors'
              navigation_icon 'fa fa-history'
              object_label_method :label
              weight 600
              visible true
              show_in_dashboard false

              public_access true

              json_formatter do
                proc do |traces, options|
                  attrs = %w(model_label target_show_url object_name author_data) - (options[:except] || []).to_a
                  attrs = attrs.select { |attr| options[:only].include?(attr) } unless options[:only].empty?
                  traces.collect do |trace|
                    json = options ? trace.as_json(options) : trace.as_json
                    attrs.each do |attr|
                      json[attr] =
                        case attr
                        when 'model_label'
                          (target_model = trace.target_model_name) &&
                            RailsAdmin.config(target_model).label
                        when 'target_show_url'
                          (tracer_model_config = RailsAdmin.config(trace.target_model_name)) &&
                            (tracer_abstract_model = tracer_model_config.abstract_model) &&
                            (target = trace.target)&&
                            "/#{tracer_abstract_model.to_param}/#{target.id}"
                        when 'object_name'
                          (tracer_model_config = RailsAdmin.config(trace.target_model_name)) &&
                            (tracer_abstract_model = tracer_model_config.abstract_model) &&
                            ((target = trace.target).nil? ? trace.target_id : target.send(tracer_model_config.object_label_method))
                        when 'author_data'
                          if (author = User.where(id: trace.author_id).first)
                            { picture: author.picture_url, email: author.email }
                          else
                            nil
                          end
                        else
                          nil
                        end
                    end
                    json
                  end
                end
              end

              api_path "#{::Setup.to_s.underscore}/trace"

              configure :target_id, :json_value do
                label 'Target ID'
              end

              configure :target_model, :model do
                visible do
                  bindings[:controller].action_name == 'index'
                end
              end

              configure :target, :record do
                visible do
                  bindings[:controller].action_name != 'member_trace_index'
                end
              end

              configure :action do
                pretty_value do
                  if (msg = bindings[:object].message)
                    "#{msg} (#{bindings[:object].action})"
                  else
                    value.to_s.to_title
                  end
                end
              end

              configure :attributes_trace, :json_value

              fields :target_model, :target, :action, :attributes_trace, :created_at

              filter_fields :target_id, :action, :attributes_trace, :created_at
            end
          end

        end
      end
    end
  end
end
