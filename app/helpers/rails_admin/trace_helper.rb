module RailsAdmin
  module TraceHelper

    def show_mongoid_tracer_trace
      redirect_url = nil
      if params[:try_recover].to_b
        if @object.target
          flash[:error] = 'Invalid recover option, target already exist'
        else
          flash[:warning] = 'Recover action is not yet supported, keep your traces, it will comes soon'
        end
      end
      if params[:pin].to_b
        if @object.target
          if (pin = Setup::Pin.for(@object.target))
            pin.destroy
          end
          Setup::Pin.create(trace: @object)
          target_model_config = RailsAdmin.config(@object.target)
          redirect_url = show_path(target_model_config.abstract_model.to_param, id: @object.target_id)
        else
          flash[:error] = 'Invalid pin option, target does not exists'
        end
      end
      if redirect_url
        redirect_to redirect_url
      else
        @trace = @object
        @tracer_model_config = RailsAdmin.config(@object.target_model_name)
        @tracer_abstract_model = @tracer_model_config.abstract_model
        render :trace_show
      end
    end

    def diffstat(additions, deletions, resume = false)
      blocks = ''
      added, deleted =
        if (total = additions + deletions) > 0
          if total <= 5
            [additions, deletions]
          else
            [(additions*100)/total/20, (deletions*100)/total/20]
          end
        else
          [0, 0]
        end
      neutral = 5-(added + deleted)
      while added > 0
        blocks += '<span class="block-diff-added"></span>'
        added = added -1
      end
      while deleted > 0
        blocks += '<span class="block-diff-deleted"></span>'
        deleted = deleted -1
      end
      while neutral > 0
        blocks += '<span class="block-diff-neutral"></span>'
        neutral = neutral -1
      end
      title, prefix =
        if resume
          additions_resume = additions > 0 ? %(<span class="additions">+ #{additions} </span>) : ''
          deletions_resume = deletions > 0 ? %(<span class="deletions">- #{deletions} </span>) : ''
          ["#{additions + deletions} changes", %(#{additions_resume}#{deletions_resume})]
        else
          ["#{additions} additions &amp; #{deletions} deletions", additions+deletions]
        end
      %(<span class="total-changes">#{prefix}</span><span class="diffstat tooltipped tooltipped-e" title="#{title}">
            #{blocks}
          </span>
          )
    end

    def build_diff(abstract_model, changes_set)
      @diff_index = 0
      incremental_build_diff(abstract_model, changes_set)
    end

    def incremental_build_diff(abstract_model, changes_set)
      fields_labels = []
      fields_diffs = []
      model_config = abstract_model.config
      model = abstract_model.model
      context_bindings = { abstract_model: abstract_model }
      changes_set.each do |attr, values|
        field_name = attr
        metadata = nil
        if (field = model.fields[attr]) && field.foreign_key?
          metadata = field.metadata
          field_name = metadata.name.to_s
        end
        label =
          if (field = model_config._fields.detect { |f| f.name.to_s == field_name })
            field.with(context_bindings).label
          else
            field_name.to_title
          end
        if metadata
          label = "#{label} ID"
          label = "#{label}s" if metadata.many?
        end
        fields_labels << label
        fields_diffs <<
          if (relation = model.reflect_on_association(attr))
            if relation.many?
              additions = 0
              deletions = 0
              related_model_config = RailsAdmin.config(relation.klass)
              related_abstract_model = related_model_config.abstract_model
              index = -1
              tab_contents = values.collect do |item|
                index += 1
                id = item['_id'][0] || item['_id'][1]
                content =
                  if item.size == 1
                    if item['_id'][1]
                      %(#{diffstat(0, 0)}<label class="label label-default">Unchanged<label>)
                    else
                      deletions += 1
                      %(#{diffstat(0, 1)}<label class="label label-danger">Destroyed</label>)
                    end
                  else
                    item = item.except('_id') if item['_id'][0] == item['_id'][1]
                    diff = incremental_build_diff(related_abstract_model, item)
                    additions += diff[:additions]
                    deletions += diff[:deletions]
                    diff[:html]
                  end
                tab_pane = "<div class='tab-pane#{index == 0 ? ' active' : ''}' id='unique_id_#{id}'>#{content}</div>"
                tab_pane
              end.join
              first = true
              lies = values.collect do |item|
                id = item['_id'][1] || item['_id'][0]
                li = %(<li class='#{first && 'active'}'>
                            <a data-toggle="tab" title="#{related_model_config.label} ##{id}" href="#unique_id_#{id}">
                              #{item['_id'][1].nil? ? '<label class="label label-danger">Destroyed</label>' : related_model_config.label + ' #' + id}
                            </a>
                          </li>)
                first = nil
                li
              end.join
              { additions: additions, deletions: deletions, html: %(<ul class="nav nav-tabs"">#{lies}</ul><div class="tab-content">#{tab_contents}</div>) }
            elsif values
              incremental_build_diff(RailsAdmin.config(relation.klass).abstract_model, values)
            else
              { additions: 0, deletions: 1, html: "#{diffstat(0, 1)}Destroyed" }
            end
          else
            additions = 0
            deletions = 0
            values = values.collect do |value|
              case value
              when Array, Hash
                JSON.pretty_generate(value)
              else
                value.to_s
              end
            end
            diff = Diffy::Diff.new(values[0], values[1])
            diff.each do |line|
              case line
              when /^\+/
                additions += 1
              when /^-/
                deletions += 1
              end
            end
            {
              additions: additions,
              deletions: deletions,
              html: additions + deletions > 0 ? diff.to_s(:html) : %(#{diffstat(0, 0)}<label class="label label-default">Unchanged<label>)
            }
          end
      end
      additions = 0
      deletions = 0
      index = -1
      open_count = 3
      fields_diffs = fields_diffs.collect do |diff|
        additions += diff[:additions]
        deletions += diff[:deletions]
        index += 1
        label = fields_labels[index]
        accordion_id = (@diff_index += 1).to_s
        open = index < open_count
        %(<div class="panel-group" id="accordion_#{accordion_id}" role="tablist" aria-multiselectable="true">
                <div class="panel panel-default panel-trace">
                  <div class="panel-heading" role="tab" id="headingOne">
                      <a role="button" data-toggle="collapse" data-parent="#accordion_#{accordion_id}" href="#collapse-#{accordion_id}" aria-expanded="#{open ? 'true' : 'false'}" aria-controls="collapseOne" class="#{open ? '' : 'collapsed'}">
                        <h4 class="panel-title">
                            #{diffstat(diff[:additions], diff[:deletions])}
        #{label}
                        </h4>
                      </a>
                  </div>
                  <div id="collapse-#{accordion_id}" class="panel-collapse collapse #{open ? 'in' : ''}" role="tabpanel" aria-labelledby="headingOne">
                    <div class="panel-body">
                      #{diff[:html]}
                    </div>
                  </div>
                </div>
              </div>)
      end.join.html_safe
      { additions: additions, deletions: deletions, html: fields_diffs }
    end
  end
end

