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
            Thread.current["[cenit][#{Mongoid::Tracer::Trace}]:persistence-options"] = persistence_options = { model: @abstract_model.model }
            @model_config = RailsAdmin::Config.model(Mongoid::Tracer::Trace)
            @context_abstract_model = @model_config.abstract_model

            if (trace_id = params[:trace_id])
              if (@trace = @object.traces.where(id: trace_id).first)
                @trace = @trace.with(persistence_options)
              else
                flash[:error] = "Trace with ID #{trace_id} not found"
              end
            end

            unless @trace
              @objects = list_entries(@model_config, :trace, @object.trace_scope)
              render :index
            end
          end
        end

        def build_html_diff(abstract_model, changes_set, deep = 0, sibling_id = nil)
          deep += 1
          fields_labels = []
          fields_html = []
          model_config = abstract_model.config
          model = abstract_model.model
          context_bindings = (bindings || {}).merge(abstract_model: abstract_model)
          changes_set.each do |attr, values|
            next unless (field = model_config.fields.detect { |f| f.name.to_s == attr })
            fields_labels << field.with(context_bindings).label
            fields_html <<
              if (relation = model.reflect_on_association(attr))
                if relation.many?
                  related_model_config = RailsAdmin.config(relation.klass)
                  related_abstract_model = related_model_config.abstract_model
                  index = -1
                  tab_contents = values.collect do |item|
                    index += 1
                    id = item['_id'][0] || item['_id'][1]
                    content =
                      if item.size == 1
                        if item['_id'][1]
                          '<label class="label label-default">Unchanged<label>'
                        else
                          '<label class="label label-danger">Destroyed</label>'
                        end
                      else
                        build_html_diff(related_abstract_model, item.except('_id'), deep, index)
                      end
                    tab_pane = "<div class='tab-pane#{index == 0 ? ' active' : ''}' id='unique_id_#{id}'>#{content}</div>"
                    tab_pane
                  end.join
                  first = true
                  lies = values.collect do |item|
                    id = item['_id'][1] || item['_id'][0]
                    li = %(<li class='#{first && 'active'}'><a data-toggle="tab" title="#{related_model_config.label} ##{id}" href="#unique_id_#{id}">#{related_model_config.label} ##{id}</a></li>)
                    first = nil
                    li
                  end.join
                  %(<ul class="nav nav-tabs"">#{lies}</ul><div class="tab-content">#{tab_contents}</div>)
                elsif values
                  build_html_diff(RailsAdmin.config(relation.klass).abstract_model, values, deep)
                else
                  'Destroyed'
                end
              else
                values = values.collect do |value|
                  case value
                  when Array, Hash
                    JSON.pretty_generate(value)
                  else
                    value.to_s
                  end
                end
                Diffy::Diff.new(values[0], values[1]).to_s(:html)
              end
          end
          index = -1
          open_count = 3
          fields_html.collect do |field_html|
            index += 1
            label = fields_labels[index]
            accordion_id = "#{deep}_#{sibling_id}_#{index}"
            open = index < open_count
            %(<div class="panel-group" id="accordion_#{accordion_id}" role="tablist" aria-multiselectable="true">
                <div class="panel panel-default panel-trace">
                  <div class="panel-heading" role="tab" id="headingOne">
                      <a role="button" data-toggle="collapse" data-parent="#accordion_#{accordion_id}" href="#collapse-#{accordion_id}" aria-expanded="#{open ? 'true' : 'false'}" aria-controls="collapseOne" class="#{open ? '' : 'collapsed'}">
                        <h4 class="panel-title">
                            #{label}
                        </h4>
                      </a>
                  </div>
                  <div id="collapse-#{accordion_id}" class="panel-collapse collapse #{open ? 'in' : ''}" role="tabpanel" aria-labelledby="headingOne">
                    <div class="panel-body">
                      #{field_html}
                    </div>
                  </div>
                </div>
              </div>)
          end.join.html_safe
        end

        register_instance_option :listing? do
          bindings[:controller].instance_variable_get(:@objects)
        end

        def url_options(opts)
          opts = super
          opts[:model_name] = bindings[:controller].instance_variable_get(:@abstract_model).to_param
          if (object = bindings[:object]).is_a?(Mongoid::Tracer::Trace)
            if (target = object.target)
              opts[:id] = target.id
              opts[:trace_id] = object.id
            end
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