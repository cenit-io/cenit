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

        def build_html_diff(abstract_model, changes_set)
          simples = ''
          simples_c = 0
          relates = []
          model_config = abstract_model.config
          model = abstract_model.model
          context_bindings = (bindings || {}).merge(abstract_model: abstract_model)
          changes_set.each do |attr, values|
            next unless (field = model_config.fields.detect { |f| f.name.to_s == attr })
            label = field.with(context_bindings).label
            if (relation = model.reflect_on_association(attr))
              relation_html =
                if relation.many?
                  related_model_config = RailsAdmin.config(relation.klass)
                  related_abstract_model = related_model_config.abstract_model
                  first = true
                  tab_contents = values.collect do |item|
                    id = item['_id'][0] || item['_id'][1]
                    content =
                      if item.size == 1
                        if item['_id'][1]
                          'Unchanged'
                        else
                          'Destroyed'
                        end
                      else
                        build_html_diff(related_abstract_model, item.except('_id'))
                      end
                    tab_pane = "<div class='tab-pane#{first && ' active'}' id='unique_id_#{id}'>#{content}</div>"
                    first = nil
                    tab_pane
                  end.join
                  first = true
                  lies = values.collect do |item|
                    id = item['_id'][1] || item['_id'][0]
                    li = %(<li class='#{first && 'active'}'><a data-toggle="tab" href="#unique_id_#{id}">#{related_model_config.label} ##{id}</a></li>)
                    first = nil
                    li
                  end.join
                  %(<ul class="nav nav-tabs"">#{lies}</ul><div class="tab-content">#{tab_contents}</div>)
                elsif values
                  build_html_diff(RailsAdmin.config(relation.klass).abstract_model, values)
                else
                  'Destroyed'
                end
              relates << %(#{field.label}</legend><div class="control-group">#{relation_html}</div></fieldset>)
            else
              simples_c += 1
              simples += "<span class=\"label label-info\">#{label}</span>"
              simples = "#{simples}<div class='clearfix'></div>"
              values = values.collect do |value|
                case value
                when Array, Hash
                  JSON.pretty_generate(value)
                else
                  value.to_s
                end
              end
              simples = "#{simples}<span class='well' style='float:left;width:100%'>#{Diffy::Diff.new(values[0], values[1], include_plus_and_minus_in_html: true).to_s(:html)}</span>"
            end
          end
          related_prefix = %(<div class="clearfix"></div><fieldset><legend style=""><i class="icon-chevron-#{simples_c < 3 && relates.length < 3 ? 'down' : 'right'}"></i>)
          relates = relates.collect { |r| related_prefix + r }.join
          (simples + relates).html_safe
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