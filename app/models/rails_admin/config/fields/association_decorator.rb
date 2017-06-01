module RailsAdmin
  module Config
    module Fields
      Association.class_eval do

        register_instance_option :list_fields do
          nil
        end

        register_instance_option :pretty_value do
          v = bindings[:view]
          #Patch
          action = v.instance_variable_get(:@action)
          values, total = show_values(limit = 40)
          if (action.is_a?(RailsAdmin::Config::Actions::Show) || action.is_a?(RailsAdmin::Config::Actions::RemoteSharedCollection)) &&
             !v.instance_variable_get(:@showing)
            amc = RailsAdmin.config(association.klass)
            am = amc.abstract_model
            count = 0
            fields = amc.list.with(controller: bindings[:controller], view: v, object: am.new).visible_fields
            if (listing = list_fields)
              fields = fields.select { |f| listing.include?(f.name.to_s) }
            end
            unless fields.length == 1 && values.length == 1
              v.instance_variable_set(:@showing, true)
            end
            table = <<-HTML
            <table class="table table-condensed table-striped">
              <thead>
                <tr>
                  #{fields.collect { |field| "<th class=\"#{field.css_class} #{field.type_css_class}\">#{field.label}</th>" }.join}
                  <th class="last shrink"></th>
                <tr>
              </thead>
              <tbody>
          #{values.collect do |associated|
              if count < limit - 5 || limit >= total
                associated.try(:instance_pending_references, *fields)
                count += 1
                can_see = !am.embedded? && !associated.new_record? && (show_action = v.action(:show, am, associated))
                '<tr class="script_row">' +
                  fields.collect do |field|
                    field.bind(object: associated, view: v)
                    "<td class=\"#{field.css_class} #{field.type_css_class}\" title=\"#{v.strip_tags(associated.to_s)}\">#{field.pretty_value}</td>"
                  end.join +
                  if can_see
                    '<td id="actions-menu-list">
                    <div class="options-menu" id="links">
                    <span class="btn dropdown-toggle" data-toggle="dropdown" type="button">
                    <i class="fa fa-ellipsis-v"></i>
                    </span>
                    <ul class="dropdown-menu">' + v.menu_for(:member, am, associated)
                  else
                    '<td class="last links"><ul class="inline list-inline">'
                  end +
                  '</ul></td>' +
                  '</tr>'
              else
                ''
              end
            end.join}
              </tbody>
            </table>
            HTML
            v.instance_variable_set(:@showing, false)
            if multiple?
              table += "<div class=\"clearfix total-count\">" +
                if total > count
                  if values.is_a?(Mongoid::Criteria) && !am.embedded? && (v.action(:index, am))
                    all_associated_link(values, am, "#{total} #{amc.label_plural}")
                  else
                    "#{total} #{amc.label_plural}"
                  end +
                    " (showing #{count})"
                else
                  "#{total} #{amc.label_plural}"
                end
              table += '</div>'
            end
            v.instance_variable_set(:@showing, false)
            table.html_safe
          else
            max_associated_to_show = 3
            count_associated= values.count
            associated_links = values.collect do |associated|
              amc = polymorphic? ? RailsAdmin.config(associated) : associated_model_config # perf optimization for non-polymorphic associations
              am = amc.abstract_model
              wording = associated.send(amc.object_label_method)
              can_see = !am.embedded? && !associated.new_record? && (show_action = v.action(:show, am, associated))
              can_see ? v.link_to(wording, v.url_for(action: show_action.action_name, model_name: am.to_param, id: associated.id), class: 'pjax') : ERB::Util.html_escape(wording)
            end.to(max_associated_to_show-1).to_sentence.html_safe
            if count_associated > max_associated_to_show
              more_link = all_associated_link(values, am, "#{count_associated - max_associated_to_show} more")
              associated_links = associated_links + ' and '+more_link.html_safe
            end
            associated_links
          end
        end

        def all_associated_link(values, am, link_content)
          v = bindings[:view]
          if bindings[:controller] && values.is_a?(Mongoid::Criteria) && !am.embedded? && (index_action = v.action(:index, am))
            message = "<span>Showing #{label.downcase} of <em>#{bindings[:object].send(bindings[:controller].model_config.object_label_method)}</em></span>"
            filter_token = Cenit::Token.create(data: { criteria: values.selector, message: message }, token_span: 1.hours)
            v.link_to(link_content, v.url_for(action: index_action.action_name, model_name: am.to_param, filter_token: filter_token.token), class: 'pjax')
          else
            ''
          end
        end

        def value
          #Patch
          if (v = bindings[:object].send(association.name)).is_a?(Enumerable)
            v.to_a
          else
            v
          end
        end

        def show_values(limit = 10)
          if (v = bindings[:object].try(association.name, limit: limit) || bindings[:object].send(association.name))
            if v.is_a?(Enumerable)
              total = v.size
              if total > limit
                v = v.limit(limit) rescue v
              end
            else
              v = [v]
              total = 1
            end
          else
            v = []
            total = 0
          end
          [v, total]
        end

        register_instance_option :contextual_params do
          {}
        end

        register_instance_option :contextual_association_scope do
          proc { |scope| scope }
        end

        register_instance_option :associated_collection_scope do
          limit = (associated_collection_cache_all ? nil : 30)
          contextual_params = self.contextual_params.merge(bindings[:controller].params[:contextual_params] || {})
          model_config = associated_model_config
          contextual_association_scope = self.contextual_association_scope
          proc do |scope|
            scope = contextual_association_scope.call(scope) if contextual_association_scope
            scope.limit(limit)
            or_criteria = []
            model_config._fields.each do |f|
              next unless f.is_a?(RailsAdmin::Config::Fields::Types::BelongsToAssociation) && contextual_params.key?(f.foreign_key)
              id = contextual_params[f.foreign_key]
              if id.nil? || (id.is_a?(Array) && id.include?(nil))
                or_criteria << { f.foreign_key => { '$exists': false } }
              end
              or_criteria << { f.foreign_key => id.is_a?(Array) ? { '$in': id } : id }
            end
            (or_criteria.empty? && scope) || scope.or(or_criteria.flatten)
          end
        end
      end
    end
  end
end
