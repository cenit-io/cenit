require 'rails_admin/config'
require 'rails_admin/main_controller'
require 'rails_admin/application_controller'
require 'rails_admin/config/fields/types/carrierwave'
require 'rails_admin/config/fields/types/file_upload'
require 'rails_admin/adapters/mongoid'
require 'rails_admin/lib/mongoff_abstract_model'

module RailsAdmin

  class ActionNotAllowed

    def initialize(msg = 'Action not allowed')
      super
    end
  end

  module Config

    class << self

      def model(entity, &block)
        key = nil
        model_class =
          if entity.is_a?(Mongoff::Model) || entity.is_a?(Mongoff::Record) || entity.is_a?(RailsAdmin::MongoffAbstractModel)
            RailsAdmin::MongoffModelConfig
          else
            key =
              case entity
              when RailsAdmin::AbstractModel
                entity.model.try(:name).try :to_sym
              when Class
                entity.name.to_sym
              when String, Symbol
                entity.to_sym
              else
                entity.class.name.to_sym
              end
            RailsAdmin::Config::LazyModel
          end

        if block
          model = model_class.new(entity, &block)
          @registry[key] = model if key
        elsif key
          unless (model = @registry[key])
            @registry[key] = model = model_class.new(entity)
          end
        else
          model = model_class.new(entity)
        end
        model
      end
    end

    class Model

      register_instance_option :public_access? do
        false
      end

      Actions.all.each do |action|
        instance_eval "register_instance_option(:#{action.key}_template_name) { :#{action.key} }"
        instance_eval "register_instance_option(:#{action.key}_link_icon) { nil }"
      end

      register_instance_option :template_name do
        if (action = bindings[:action])
          send("#{action.key}_template_name")
        end
      end

      register_instance_option :show_in_dashboard do
        true
      end

      register_instance_option :label_navigation do
        label_plural
      end

      def contextualized_label(context = nil)
        label
      end

      def contextualized_label_plural(context = nil)
        label_plural
      end

      register_instance_option :extra_associations do
        []
      end
    end

    module Actions

      class Base
        register_instance_option :template_name do
          ((absm = bindings[:abstract_model]) && absm.config.with(action: self).template_name) || key.to_sym
        end
      end

      class New
        register_instance_option :controller do
          proc do

            #Patch
            if request.get? || params[:_restart] # NEW

              @object =
                if (token = Cenit::Token.where(token: params[:json_token]).first)
                  hash = JSON.parse(token.data) rescue {}
                  @abstract_model.model.data_type.new_from_json(hash)
                else
                  @abstract_model.new
                end
              @authorization_adapter && @authorization_adapter.attributes_for(:new, @abstract_model).each do |name, value|
                @object.send("#{name}=", value)
              end
              if (object_params = params[@abstract_model.to_param])
                @object.set_attributes(@object.attributes.merge(object_params))
              end
              respond_to do |format|
                format.html { render @action.template_name }
                format.js { render @action.template_name, layout: false }
              end

            elsif request.post? # CREATE

              @modified_assoc = []
              @object = @abstract_model.new
              sanitize_params_for!(request.xhr? ? :modal : :create)

              @object.set_attributes(params[@abstract_model.param_key])
              @authorization_adapter && @authorization_adapter.attributes_for(:create, @abstract_model).each do |name, value|
                @object.send("#{name}=", value)
              end

              #Patch
              if params[:_next].nil? && @object.save
                @auditing_adapter && @auditing_adapter.create_object(@object, @abstract_model, _current_user)
                respond_to do |format|
                  format.html { redirect_to_on_success }
                  format.js { render json: { id: @object.id.to_s, label: @model_config.with(object: @object).object_label } }
                end
              else
                handle_save_error
              end

            end
          end
        end
      end

      class Edit
        register_instance_option :controller do
          proc do

            if request.get? # EDIT

              respond_to do |format|
                format.html { render @action.template_name }
                format.js { render @action.template_name, layout: false }
              end

            elsif request.put? # UPDATE
              sanitize_params_for!(action = (request.xhr? ? :modal : :update))

              @object.set_attributes(form_attributes = params[@abstract_model.param_key])

              #Patch
              if (synchronized_fields = @model_config.with(object: @object).try(:form_synchronized))
                params_to_check = {}
                model_config.send(action).with(controller: self, view: view_context, object: @object).fields.each do |field|
                  if synchronized_fields.include?(field.name.to_sym)
                    params_to_check[field.name.to_sym] = (field.is_a?(RailsAdmin::Config::Fields::Association) ? field.method_name : field.name).to_s
                  end
                end
                params_to_check.each do |field, param|
                  @object.send("#{field}=", nil) unless form_attributes[param].present?
                end
              end

              @authorization_adapter && @authorization_adapter.attributes_for(:update, @abstract_model).each do |name, value|
                @object.send("#{name}=", value)
              end
              changes = @object.changes
              if @object.save
                if (warnings = @object.try(:warnings)).present?
                  do_flash(:warning, 'Warning', warnings)
                end
                @auditing_adapter && @auditing_adapter.update_object(@object, @abstract_model, _current_user, changes)
                respond_to do |format|
                  format.html { redirect_to_on_success }
                  format.js { render json: { id: @object.id.to_s, label: @model_config.with(object: @object).object_label } }
                end
              else
                handle_save_error :edit
              end

            end

          end
        end
      end

      class Dashboard
        register_instance_option :controller do
          proc do
            @history = @auditing_adapter && @auditing_adapter.latest || []
            if @action.statistics?
              #Patch
              @model_configs = {}
              @abstract_models =
                if current_user
                  RailsAdmin::Config.visible_models(controller: self).collect(&:abstract_model).select do |absm|
                    ((model = absm.model) rescue nil) &&
                      (model.is_a?(Mongoff::Model) || model.include?(AccountScoped) || [Account].include?(model)) &&
                      (@model_configs[absm.model_name] = absm.config)
                  end
                else
                  Setup::Models.collect { |m| RailsAdmin::Config.model(m) }.select(&:visible).collect do |config|
                    absm = config.abstract_model
                    @model_configs[absm.model_name] = config
                    absm
                  end
                end
              @most_recent_changes = {}
              @count = {}
              @max = 0
              #Patch
              if current_user
                @abstract_models.each do |t|
                  scope = @authorization_adapter && @authorization_adapter.query(:index, t)
                  current_count = t.count({ cache: true }, scope)
                  @max = current_count > @max ? current_count : @max
                  @count[t.model.name] = current_count
                  # Patch
                  # next unless t.properties.detect { |c| c.name == :updated_at }
                  # @most_recent_changes[t.model.name] = t.first(sort: "#{t.table_name}.updated_at").try(:updated_at)
                end
              else
                @abstract_models.each do |absm|
                  current_count = absm.model.super_count
                  @max = current_count > @max ? current_count : @max
                  @count[absm.model.name] = current_count
                end
              end
            end
            render @action.template_name, status: (flash[:error].present? ? :not_found : 200)
          end
        end

        register_instance_option :link_icon do
          'fa fa-dashboard'
        end
      end

      class Index < RailsAdmin::Config::Actions::Base

        register_instance_option :controller do
          proc do
            #Patch
            if current_user || model_config.public_access?
              begin
                @objects ||= list_entries

                unless @model_config.list.scopes.empty?
                  if params[:scope].blank?
                    unless @model_config.list.scopes.first.nil?
                      @objects = @objects.send(@model_config.list.scopes.first)
                    end
                  elsif @model_config.list.scopes.collect(&:to_s).include?(params[:scope])
                    @objects = @objects.send(params[:scope].to_sym)
                  end
                end

                respond_to do |format|
                  format.html do
                    render @action.template_name, status: (flash[:error].present? ? :not_found : 200)
                  end

                  format.json do
                    output = begin
                      if params[:compact]
                        primary_key_method = @association ? @association.associated_primary_key : @model_config.abstract_model.primary_key
                        label_method = @model_config.object_label_method
                        @objects.collect { |o| { id: o.send(primary_key_method).to_s, label: o.send(label_method).to_s } }
                      else
                        @objects.to_json(@schema)
                      end
                    end
                    if params[:send_data]
                      send_data output, filename: "#{params[:model_name]}_#{DateTime.now.strftime('%Y-%m-%d_%Hh%Mm%S')}.json"
                    else
                      render json: output, root: false
                    end
                  end

                  format.xml do
                    output = @objects.to_xml(@schema)
                    if params[:send_data]
                      send_data output, filename: "#{params[:model_name]}_#{DateTime.now.strftime('%Y-%m-%d_%Hh%Mm%S')}.xml"
                    else
                      render xml: output
                    end
                  end

                  format.csv do
                    header, encoding, output = CSVConverter.new(@objects, @schema).to_csv(params[:csv_options])
                    if params[:send_data]
                      send_data output,
                                type: "text/csv; charset=#{encoding}; #{'header=present' if header}",
                                disposition: "attachment; filename=#{params[:model_name]}_#{DateTime.now.strftime('%Y-%m-%d_%Hh%Mm%S')}.csv"
                    else
                      render text: output
                    end
                  end
                end
              rescue Exception => ex
                flash[:error] = ex.message
                redirect_to dashboard_path
              end
            else
              redirect_to new_session_path(User)
            end
          end
        end
      end
    end

    module Fields

      class Association

        register_instance_option :list_fields do
          nil
        end

        register_instance_option :pretty_value do
          v = bindings[:view]
          #Patch
          action = v.instance_variable_get(:@action)
          values, total = show_values(limit = 40)
          if action.is_a?(RailsAdmin::Config::Actions::Show) && !v.instance_variable_get(:@showing)
            v.instance_variable_set(:@showing, true)
            amc = RailsAdmin.config(association.klass)
            am = amc.abstract_model
            count = 0
            fields = amc.list.with(controller: self, view: v, object: am.new).visible_fields
            if (listing = list_fields)
              fields = fields.select { |f| listing.include?(f.name.to_s) }
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
                  '<td class="last links"><ul class="inline list-inline">' +
                  if can_see
                    v.menu_for(:member, am, associated, true)
                  else
                    ''
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
            if multiple?
              table += "<div class=\"clearfix total-count\">#{total} #{amc.label_plural}"
              if total > count
                table += " (showing #{count})"
              end
              table += '</div>'
            end
            v.instance_variable_set(:@showing, false)
            table.html_safe
          else
            values.collect do |associated|
              amc = polymorphic? ? RailsAdmin.config(associated) : associated_model_config # perf optimization for non-polymorphic associations
              am = amc.abstract_model
              wording = associated.send(amc.object_label_method)
              can_see = !am.embedded? && (show_action = v.action(:show, am, associated))
              can_see ? v.link_to(wording, v.url_for(action: show_action.action_name, model_name: am.to_param, id: associated.id), class: 'pjax') : ERB::Util.html_escape(wording)
            end.to_sentence.html_safe
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
      end

      module Types

        class Datetime

          register_instance_option :formatted_value do
            if (time = value)
              if (current_account = Account.current)
                time = time.to_time.localtime(current_account.time_zone_offset)
              end
              I18n.l(time, format: strftime_format)
            else
              ''.html_safe
            end
          end
        end

        class FileUpload

          register_instance_option :pretty_value do
            if value.presence
              v = bindings[:view]
              url = resource_url
              if image
                thumb_url = resource_url(thumb_method)
                logo_background = bindings[:object].try(:logo_background)
                image_html = v.image_tag(thumb_url, class: logo_background ? 'logo' : 'img-thumbnail')
                if logo_background
                  image_html = "<div style=\"background-color:##{logo_background}\">#{image_html}</div>".html_safe
                end
                url != thumb_url ? v.link_to(image_html, url, target: '_blank') : image_html
              else
                v.link_to(nil, url, target: '_blank')
              end
            end
          end
        end
      end
    end
  end

  class AbstractModel

    def embedded_in?(abstract_model = nil)
      embedded?
    end
  end

  module ApplicationHelper

    # parent => :root, :collection, :member
    def menu_for(parent, abstract_model = nil, object = nil, only_icon = false) # perf matters here (no action view trickery)
      actions = actions(parent, abstract_model, object).select { |a| a.http_methods.include?(:get) }
      actions.collect do |action|
        wording = wording_for(:menu, action)
        #Patch
        link_icon = (abstract_model && abstract_model.config.send("#{action.key}_link_icon")) || action.link_icon
        %(
          <li title="#{wording if only_icon}" rel="#{'tooltip' if only_icon}" class="icon #{action.key}_#{parent}_link #{'active' if current_action?(action)}">
            <a class="#{action.pjax? ? 'pjax' : ''}" href="#{url_for(action: action.action_name, controller: 'rails_admin/main', model_name: abstract_model.try(:to_param), id: (object.try(:persisted?) && object.try(:id) || nil))}">
              <i class="#{link_icon}"></i>
              <span#{only_icon ? " style='display:none'" : ''}>#{wording}</span>
            </a>
          </li>
        )
      end.join.html_safe
    end

    def wording_for(label, action = @action, abstract_model = @abstract_model, object = @object)
      model_config = abstract_model.try(:config) || action.bindings[:custom_model_config]
      #Patch
      object = abstract_model && object && object.is_a?(abstract_model.model) ? object : nil rescue nil
      action = RailsAdmin::Config::Actions.find(action.to_sym) if action.is_a?(Symbol) || action.is_a?(String)

      capitalize_first_letter I18n.t(
        "admin.actions.#{action.i18n_key}.#{label}",
        model_label: model_config && model_config.contextualized_label(label),
        model_label_plural: model_config && model_config.contextualized_label_plural(label),
        object_label: model_config && object.try(model_config.object_label_method),
      )
    end

    def linking(model)
      if (account = Account.current) &&
        (abstract_model = RailsAdmin.config(model).abstract_model) &&
        (index_action = RailsAdmin::Config::Actions.find(:index, controller: controller, abstract_model: abstract_model)).try(:authorized?)
        [account, abstract_model, index_action]
      else
        [nil, nil, nil]
      end
    end

    def tasks_link
      _, abstract_model, index_action = linking(Setup::Task)
      return nil unless index_action
      link_to url_for(action: index_action.action_name, model_name: abstract_model.to_param, controller: 'rails_admin/main'), class: 'pjax' do
        html = '<i class="icon-tasks" title="Tasks" rel="tooltip"/></i>'
        #...
        html.html_safe
      end
    end

    def authorizations_link
      _, abstract_model, index_action = linking(Setup::Authorization)
      return nil unless index_action
      link_to url_for(action: index_action.action_name, model_name: abstract_model.to_param, controller: 'rails_admin/main'), class: 'pjax' do
        html = '<i class="icon-check"  title="Authorizations" rel="tooltip"></i>'
        if (unauthorized_count = Setup::Authorization.where(authorized: false).count) > 0
          label_html = <<-HTML
            <b class="label rounded label-xs success up" style='border-radius: 500px;
              position: relative;
              top: -10px;
              min-width: 4px;
              min-height: 4px;
              display: inline-block;
              font-size: 9px;
              background-color: #{Setup::Notification.type_color(:error)}'>#{unauthorized_count}
            </b>
          HTML
          html += label_html
        end
        html.html_safe
      end
    end

    def notifications_link
      account, abstract_model, index_action = linking(Setup::Notification)
      return nil unless index_action
      link_to url_for(action: index_action.action_name, model_name: abstract_model.to_param, controller: 'rails_admin/main'), class: 'pjax' do
        html = '<i class="icon-bell" title="Notification" rel="tooltip"></i>'
        counters = Hash.new { |h, k| h[k] = 0 }
        scope =
          if (from_date = account.notifications_listed_at)
            Setup::Notification.where(:created_at.gte => from_date)
          else
            Setup::Notification.all
          end
        Setup::Notification.type_enum.each do |type|
          if (count = scope.where(type: type).count) > 0
            counters[Setup::Notification.type_color(type)] = count
          end
        end
        counters.each do |color, count|
          html +=
            <<-HTML
              <b class="label rounded label-xs up" style='border-radius: 500px;
                position: relative;
                top: -10px;
                min-width: 4px;
                min-height: 4px;
                display: inline-block;
                font-size: 9px;
                background-color: #{color}'>#{count}
              </b>
          HTML
        end
        html.html_safe
      end
    end

    def edit_user_link
      # Patch
      inspecting = false
      account_config = nil
      account_abstract_model = nil
      inspect_action = nil
      if (current_user = _current_user)
        unless (current_account = Account.current_tenant).nil? || current_user.owns?(current_account)
          account_abstract_model = (account_config = RailsAdmin.config(Account)).abstract_model
          inspect_action = RailsAdmin::Config::Actions.find(:inspect, controller: controller, abstract_model: account_abstract_model, object: current_account)
          inspecting = inspect_action.try(:authorized?)
          current_user = current_account.owner
        end
      end
      abstract_model = (user_config = RailsAdmin.config(current_user.class)).abstract_model if current_user
      edit_action = RailsAdmin::Config::Actions.find(:show, controller: controller, abstract_model: abstract_model, object: current_user) if abstract_model
      unless current_user && abstract_model && edit_action
        user_config = account_config
        abstract_model = account_abstract_model
        edit_action = inspect_action
        current_user = current_account
      end
      return nil unless current_user && abstract_model && edit_action
      link = link_to url_for(action: edit_action.action_name, model_name: abstract_model.to_param, id: current_user.id, controller: 'rails_admin/main'), class: 'pjax' do
        html = []
        # Patch
        # text = _current_user.name
        # Patch
        text = current_account.label
        html << content_tag(:span, text, style: 'padding-right:5px')
        unless inspecting
          if current_user && abstract_model && edit_action
            html << image_tag(current_user.picture_url, alt: '', width: '30px')
          end
        end
        html.join.html_safe
      end
      if inspecting
        link = [link]
        link << link_to(url_for(action: inspect_action.action_name, model_name: account_abstract_model.to_param, id: current_account.id, controller: 'rails_admin/main'), class: 'pjax') do
          '<i class="icon-eye-close" style="color: red"></i>'.html_safe
        end
      end
      link
    end


    def main_navigation
      #Patch
      nodes_stack = RailsAdmin::Config.visible_models(controller: controller) +
        Setup::DataType.where(navigation_link: true).collect { |data_type| RailsAdmin.config(data_type.records_model) }
      node_model_names = nodes_stack.collect { |c| c.abstract_model.model_name }
      if @model_configs
        nodes_stack.each_with_index do |node, index|
          if (model_config = @model_configs[node.abstract_model.model_name])
            nodes_stack[index] = model_config
          end
        end
      end

      i = -1
      mongoff_start_index = nil
      definitions_index = nil
      main_labels = []
      data_type_icons = { Setup::FileDataType => 'fa fa-file', Setup::JsonDataType => 'fa fa-database' }
      non_setup_data_type_models =
        [
          Setup::FileDataType,
          Setup::JsonDataType
        ]
      data_type_models =
        {
          Setup::BuildInDataType => main_labels
        }
      non_setup_data_type_models.each { |m| data_type_models[m] = [] }
      nodes_stack.group_by(&:navigation_label).each do |navigation_label, nav_nodes|
        nav_nodes.group_by do |node|
          ((data_type = node.abstract_model.model.try(:data_type)) && data_type.class) || Setup::BuildInDataType
        end.each do |data_type_model, nodes|
          name = data_type_model.to_s.split('::').last.underscore
          i += 1
          collapse_id = "main-collapse#{i}"
          if nodes.first.is_a?(RailsAdmin::MongoffModelConfig)
            mongoff_start_index ||= i
          end

          nodes = nodes.select { |n| n.parent.nil? || !n.parent.to_s.in?(node_model_names) }
          li_stack = navigation(nodes_stack, nodes, collapse_id)

          label = navigation_label || t('admin.misc.navigation')
          if label == 'Definitions'
            definitions_index = main_labels.length
          end
          html_id = "main-#{label.underscore.gsub(' ', '-')}"

          icon = mongoff_start_index.nil? && (((opts = RailsAdmin::Config.navigation_options[label]) && opts[:icon]) || 'fa fa-cube')
          icon =
            case icon
            when Symbol
              render partial: icon.to_s
            when String
              "<i class='#{icon}'></i>"
            else
              nil
            end

          if li_stack.present?
            a = %(<div class='panel-heading'>
              <a data-toggle='collapse' data-parent='##{mongoff_start_index ? "#{name}-collapse" : 'main-accordion'}' href='##{collapse_id}' class='panel-title collapse in collapsed'>
                <span class='nav-caret'><i class='fa fa-caret-down'></i></span>) +
              (icon ? "<span class='nav-icon'>#{icon}</span>" : '') +
              %(<span class='nav-caption'>#{capitalize_first_letter label}</span>
              </a>
            </div>
            #{li_stack})
            unless mongoff_start_index
              a = "<div id='#{html_id}' class='panel panel-default'>#{a}</div>"
            end
            data_type_models[data_type_model] << a
          end
        end
      end
      definitions_index ||= main_labels.length - 1
      i = 1
      non_setup_data_type_models.each do |data_type_model|
        links = data_type_models[data_type_model]
        name = data_type_model.to_s.split('::').last.underscore
        link_link = link_to url_for(action: :link_data_type,
                                    controller: 'rails_admin/main',
                                    data_type_model: data_type_model.to_s) do
          %{<span class="nav-caption">#{t("admin.misc.link_#{name}")}</span>
              <span class="nav-icon" style="margin-left: 30px;"/>
                <i class="fa fa-plus"></i>
             </span>}.html_safe
        end
        main_labels.insert definitions_index + i, %(<div id='main-#{name}' class='panel panel-default'>
            <div class='panel-heading'>
              <a data-toggle='collapse' data-parent='#main-accordion' href='##{name}-collapse' class='panel-title collapse in collapsed'>
                <span class='nav-caret'><i class='fa fa-caret-down'></i></span>
                <span class='nav-icon'><i class='#{data_type_icons[data_type_model]}'></i></span>
                <span class='nav-caption'>#{t("admin.misc.main_navigation.#{name}")}</span>
              </a>
            </div>
            <div id='#{name}-collapse' class='nav nav-pills nav-stacked panel-collapse collapse'>
              <li>
                #{link_link}
              </li>
              #{links.collect { |link| "<div class='panel panel-default'> #{link} </div>" }.join }
            </div>
          </div>)
      end
      main_labels.join.html_safe
    end

    def navigation(nodes_stack, nodes, html_id)
      return if nodes.blank?
      i = -1
      ("<div id='#{html_id}' class='nav nav-pills nav-stacked panel-collapse collapse'>" +
        nodes.collect do |node|
          i += 1
          stack_id = "#{html_id}-sub#{i}"
          model_count = node.abstract_model.count({ cache: true }, @authorization_adapter && @authorization_adapter.query(:index, node.abstract_model)) rescue -1

          children = nodes_stack.select { |n| n.parent.to_s == node.abstract_model.model_name }
          if children.present?
            li = %(<div class='panel panel-default'>
            <div class='panel-heading'>
              <a data-toggle='collapse' data-parent='##{html_id}' href='##{stack_id}' class='panel-title collapse in collapsed'>
                <span class='nav-caret'><i class='fa fa-caret-down'></i></span>
                <span class='nav-caption'>#{capitalize_first_letter node.label_navigation}</span>
              </a>
            </div>)
            li + navigation(nodes_stack, children, stack_id) + '</div>'
          else
            model_param = node.abstract_model.to_param
            url = url_for(action: :index, controller: 'rails_admin/main', model_name: model_param)
            nav_icon = node.navigation_icon ? %(<i class="#{node.navigation_icon}"></i>).html_safe : ''
            content_tag :li, data: { model: model_param } do
              link_to url, class: 'pjax' do
                rc = ""
                if _current_user.present? && model_count>0
                  rc += "<span class='nav-amount'>#{model_count}</span>"
                end
                rc += "<span class='nav-caption'>#{capitalize_first_letter node.label_navigation}</span>"
                rc.html_safe
              end
            end
          end
        end.join + '</div>').html_safe
    end

    def dashboard_main()
      nodes_stack = @model_configs.values.sort_by(&:weight)
      node_model_names =
        if current_user
          RailsAdmin::Config.visible_models(controller: controller)
        else
          Setup::Models.collect { |m| RailsAdmin::Config.model(m) }.select(&:visible)
        end.collect { |c| c.abstract_model.model_name }

      html_ = "<table class='table table-condensed table-striped .col-sm-6'>" +
        '<thead><tr><th class="shrink"></th><th></th><th class="shrink"></th></tr></thead>' +
        nodes_stack.group_by(&:navigation_label).collect do |navigation_label, nodes|
          nodes = nodes.select { |n| n.parent.nil? || !n.parent.to_s.in?(node_model_names) }
          stack = dashboard_navigation nodes_stack, nodes

          label = navigation_label || t('admin.misc.navigation')

          icon = ((opts = RailsAdmin::Config.navigation_options[label]) && opts[:icon]) || 'fa fa-cube'
          icon =
            case icon
            when Symbol
              render partial: icon.to_s
            else
              "<i class='#{icon}'></i>"
            end

          if stack.present?
            %(
              <tbody><tr><td colspan="3"><h3>
                <span class="nav-icon">#{icon}</span>
                <span class="nav-caption">#{label}</span>
              </h3></td></tr>
            #{stack}
            </tbody>)
          end
        end.join + '</tbody></table>'
      html_.html_safe
    end

    def dashboard_navigation(nodes_stack, nodes)
      if not nodes.present?
        return
      end
      i = -1
      ('' +
        nodes.collect do |node|
          i += 1

          children = nodes_stack.select { |n| n.parent.to_s == node.abstract_model.model_name }
          if children.present?
            li = dashboard_navigation nodes_stack, children
          else
            model_param = node.abstract_model.to_param
            url = url_for(action: :index, controller: 'rails_admin/main', model_name: model_param)
            content_tag :tr, data: { model: model_param } do
              rc = '<td>' + link_to(url, class: 'pjax') do
                if current_user
                  # "#{capitalize_first_letter node.label_navigation}"
                  "#{capitalize_first_letter node.abstract_model.config.label_plural}"
                else
                  "#{capitalize_first_letter node.abstract_model.config.label_plural}"
                end
              end
              rc += '</td>'

              model_count =
                if current_user
                  node.abstract_model.count({ cache: true }, @authorization_adapter && @authorization_adapter.query(:index, node.abstract_model))
                else
                  @count[node.abstract_model.model_name] || 0
                end
              pc = percent(model_count, @max)
              indicator = get_indicator(pc)
              anim = animate_width_to(pc)

              rc += '<td>'
              rc += "<div class='progress progress-#{indicator}' style='margin-bottom:0'>"
              rc += "<div class='animate-width-to progress-bar progress-bar-#{indicator}' data-animate-length='#{anim}' data-animate-width-to='#{anim}' style='width:2%'>"
              rc += "#{model_count}"
              rc += '</div>'
              rc += '</div>'
              rc += '</td>'

              menu = menu_for(:collection, node.abstract_model, nil, true)

              rc += '<td class="links">'
              rc += "<ul class='inline list-inline'>#{menu}</ul>"
              rc += '</td>'

              rc.html_safe
            end
          end
        end.join).html_safe
    end
  end


  class MainController

    alias_method :rails_admin_list_entries, :list_entries

    def list_entries(model_config = @model_config, auth_scope_key = :index, additional_scope = get_association_scope_from_params, pagination = !(params[:associated_collection] || params[:all] || params[:bulk_ids]))
      scope = rails_admin_list_entries(model_config, auth_scope_key, additional_scope, pagination)
      if (model = model_config.abstract_model.model).is_a?(Class)
        if model.include?(CrossOrigin::Document)
          origins = []
          model.origins.each { |origin| origins << origin if params[origin_param="#{origin}_origin"].to_i.even? }
          origins << nil if origins.include?(:default)
          scope = scope.any_in(origin: origins)
        end
      elsif (output = Setup::AlgorithmOutput.where(id: params[:algorithm_output]).first) &&
        output.data_type == model.data_type
        scope = scope.any_in(id: output.output_ids)
      end
      scope
    end

    def sanitize_params_for!(action, model_config = @model_config, target_params = params[@abstract_model.param_key])
      return unless target_params.present?
      #Patch
      fields = model_config.send(action).with(controller: self, view: view_context, object: @object).fields.select do |field|
        !(field.properties.is_a?(RailsAdmin::Adapters::Mongoid::Property) && field.properties.property.is_a?(Mongoid::Fields::ForeignKey))
      end
      allowed_methods = fields.collect(&:allowed_methods).flatten.uniq.collect(&:to_s) << 'id' << '_destroy'
      fields.each { |f| f.parse_input(target_params) }
      target_params.slice!(*allowed_methods)
      target_params.permit! if target_params.respond_to?(:permit!)
      fields.select(&:nested_form).each do |association|
        children_params = association.multiple? ? target_params[association.method_name].try(:values) : [target_params[association.method_name]].compact
        (children_params || []).each do |children_param|
          sanitize_params_for!(:nested, association.associated_model_config, children_param)
        end
      end
    end

    def check_for_cancel
      #Patch
      return unless params[:_continue] || (params[:bulk_action] && !params[:bulk_ids] && !params[:object_ids])
      if params[:model_name]
        redirect_to(back_or_index, notice: t('admin.flash.noaction'))
      else
        flash[:notice] = t('admin.flash.noaction')
        redirect_to dashboard_path
      end
    end

    def handle_save_error(whereto = :new)
      #Patch
      if @object && @object.errors.present?
        flash.now[:error] = t('admin.flash.error', name: @model_config.label, action: t("admin.actions.#{@action.key}.done").html_safe).html_safe
        flash.now[:error] += %(<br>- #{@object.errors.full_messages.join('<br>- ')}).html_safe
      end

      respond_to do |format|
        format.html { render whereto, status: :not_acceptable }
        format.js { render whereto, layout: false, status: :not_acceptable }
      end
    end

    def do_flash_process_result(objs)
      objs = [objs] unless objs.is_a?(Enumerable)
      messages =
        objs.collect do |obj|
          amc = RailsAdmin.config(obj)
          am = amc.abstract_model
          wording = obj.send(amc.object_label_method)
          if (show_action = view_context.action(:show, am, obj))
            wording + ' ' + view_context.link_to(t('admin.flash.click_here'), view_context.url_for(action: show_action.action_name, model_name: am.to_param, id: obj.id), class: 'pjax')
          else
            wording
          end
        end
      model_label = @model_config.label
      model_label = model_label.pluralize if @action.bulkable?
      do_flash(:notice, t('admin.flash.processed', name: model_label, action: t("admin.actions.#{@action.key}.doing")) + ':', messages)
    end

    def do_flash(flash_key, header, messages = [], options = {})
      do_flash_on(flash, flash_key, header, messages, options)
    end

    def do_flash_now(flash_key, header, messages = [], options = {})
      do_flash_on(flash.now, flash_key, header, messages, options)
    end

    def do_flash_on(flash_hash, flash_key, header, messages = [], options = {})
      options = (options || {}).reverse_merge(reset: true)
      flash_message = header.html_safe
      flash_message = flash_hash[flash_key] + flash_message unless options[:reset] || flash_hash[flash_key].nil?
      max_message_count = options[:max] || 5
      max_message_length = 500
      max_length = 1500
      messages = [messages] unless messages.is_a?(Enumerable)
      msgs = messages[0..max_message_count].collect { |msg| msg.length < max_message_length ? msg : msg[0..max_message_length] + '...' }
      count = 0
      msgs.each do |msg|
        if flash_message.length < max_length
          flash_message += "<br>- #{msg}".html_safe
          count += 1
        end
      end
      if (count = messages.length - count) > 0
        flash_message += "<br>- and another #{count}.".html_safe
      end
      flash_hash[flash_key] = flash_message.html_safe
    end

    def get_association_scope_from_params
      return nil unless params[:associated_collection].present?
      #Patch
      if (source_abstract_model = RailsAdmin::AbstractModel.new(to_model_name(params[:source_abstract_model])))
        source_model_config = source_abstract_model.config
        source_object = source_abstract_model.get(params[:source_object_id])
        action = params[:current_action].in?(%w(create update)) ? params[:current_action] : 'edit'
        @association = source_model_config.send(action).fields.detect { |f| f.name == params[:associated_collection].to_sym }.with(controller: self, object: source_object)
        @association.associated_collection_scope
      end
    end
  end

  module Adapters
    module Mongoid

      alias_method :rails_admin_count, :count

      def count(options = {}, scope = nil)
        if options.delete(:cache)
          key = "[cenit]#{model_name}.count"
          if (count_cache = Thread.current[key])
            count_cache
          else
            Thread.current[key] = rails_admin_count(options, scope)
          end
        else
          rails_admin_count(options, scope)
        end
      end

      def sort_by(options, scope)
        return scope unless options[:sort]

        case options[:sort]
        when String
          #Patch
          collection_name = (sort = options[:sort])[0..i = sort.rindex('.') - 1]
          field_name = sort.from(i + 2)
          if collection_name && collection_name != table_name
            fail('sorting by associated model column is not supported in Non-Relational databases')
          end
        when Symbol
          field_name = options[:sort].to_s
        end
        #Patch
        if field_name.present?
          if options[:sort_reverse]
            scope.asc field_name
          else
            scope.desc field_name
          end
        else
          scope
        end
      end

      def parse_collection_name(column)
        #Patch
        collection_name = column[0..i = column.rindex('.') - 1]
        column_name = column.from(i + 2)
        if [:embeds_one, :embeds_many].include?(model.relations[collection_name].try(:macro).try(:to_sym))
          [table_name, column]
        else
          [collection_name, column_name]
        end
        [collection_name, column_name]
      end

      def associations
        model.relations.values.collect do |association|
          Association.new(association, model)
        end + config.extra_associations
      end
    end
  end

  class ApplicationController

    def get_model
      #Patch
      @model_name = to_model_name(name = params[:model_name].to_s)
      #TODO Transferring shared collections to cross shared collections. REMOVE after migration
      if @model_name == Setup::SharedCollection.to_s && !User.current_super_admin?
        @model_name = Setup::CrossSharedCollection.to_s
      end
      data_type = nil
      unless (@abstract_model = RailsAdmin::AbstractModel.new(@model_name))
        if (slugs = name.to_s.split('~')).size == 2
          if (ns = Setup::Namespace.where(slug: slugs[0]).first)
            data_type = Setup::DataType.where(namespace: ns.name, slug: slugs[1]).first
          end
        else
          data_type = Setup::DataType.where(id: name.from(2)).first if name.start_with?('dt')
        end
        if data_type
          abstract_model_class =
            if (model = data_type.records_model).is_a?(Class)
              RailsAdmin::AbstractModel
            else
              RailsAdmin::MongoffAbstractModel
            end
          @abstract_model = abstract_model_class.new(model)
        end
      end

      fail(RailsAdmin::ModelNotFound) if @abstract_model.nil? || (@model_config = @abstract_model.config).excluded?

      @properties = @abstract_model.properties
    end

    def get_object
      #Patch
      if (@object = @abstract_model.get(params[:id]))
        unless @object.is_a?(Mongoff::Record) || @object.class == @abstract_model.model
          @model_config = RailsAdmin::Config.model(@object.class)
          @abstract_model = @model_config.abstract_model
        end
        @object
      elsif (model = @abstract_model.model)
        @object = model.try(:find_by_id, params[:id])
      end
      @object || fail(RailsAdmin::ObjectNotFound)
    end
  end

  module Extensions
    module MongoidAudit
      class AuditingAdapter

        def version_class_for(object)
          @version_class.with(collection: "#{object.collection_name.to_s.singularize}_#{@version_class.collection_name}")
        end

        def version_class_with(abstract_model)
          @version_class.with(collection: "#{abstract_model.model.collection_name.to_s.singularize}_#{@version_class.collection_name}")
        end

        def listing_for_model_or_object(model, object, query, sort, sort_reverse, all, page, per_page)
          if sort.present?
            sort = COLUMN_MAPPING[sort.to_sym]
          else
            sort = :created_at
            sort_reverse = 'true'
          end
          model_name = model.model.name
          if object
            versions = version_class_for(object).where('association_chain.name' => model.model_name, 'association_chain.id' => object.id)
          else
            versions = version_class_with(model).where('association_chain.name' => model_name)
          end
          versions = versions.order_by([sort, sort_reverse == 'true' ? :desc : :asc])
          unless all
            page = 1 if page.nil?
            versions = versions.send(Kaminari.config.page_method_name, page).per(per_page)
          end
          versions.map { |version| VersionProxy.new(version) }
        end
      end
    end
  end
end
