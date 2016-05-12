require 'rails_admin/config'
require 'rails_admin/main_controller'
require 'rails_admin/config/fields/types/carrierwave'
require 'rails_admin/adapters/mongoid'
require 'rails_admin/lib/mongoff_abstract_model'

module RailsAdmin

  module Config

    class << self

      def remove_model(model)
        models_pool
        @@system_models.delete_if { |e| e.eql?(model.to_s) }
      end

      def new_model(model)
        unless models_pool.include?(model.to_s)
          @@system_models.insert((i = @@system_models.find_index { |e| e > model.to_s }) ? i : @@system_models.length, model.to_s)
        end
      end

      def model(entity, &block)
        key = nil
        model_class =
          if entity.is_a?(Mongoff::Model) || entity.is_a?(Mongoff::Record) || entity.is_a?(RailsAdmin::MongoffAbstractModel)
            RailsAdmin::MongoffModelConfig
          else
            key =
              if entity.is_a?(RailsAdmin::AbstractModel)
                entity.model.try(:name).try :to_sym
              elsif entity.is_a?(Class)
                entity.name.to_sym
              elsif entity.is_a?(String) || entity.is_a?(Symbol)
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

              unless (attrs = params[:attributes] || {}).is_a?(Hash)
                attrs = JSON.parse(attrs) rescue {}
              end
              @object = @abstract_model.new(attrs)
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
              if (synchronized_fields = @model_config.try(:form_synchronized))
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
              @abstract_models =
                if current_user
                  RailsAdmin::Config.visible_models(controller: self).select(&:show_in_dashboard).collect(&:abstract_model).select do |absm|
                    ((model = absm.model) rescue nil) &&
                      (model.is_a?(Mongoff::Model) || model.include?(AccountScoped))
                  end
                else
                  Setup::Models.collect { |m| RailsAdmin::Config.model(m) }.select(&:visible).select(&:show_in_dashboard).collect(&:abstract_model)
                end
              @most_recent_changes = {}
              @count = {}
              @max = 0
              #Patch
              if current_user
                @abstract_models.each do |t|
                  scope = @authorization_adapter && @authorization_adapter.query(:index, t)
                  current_count = t.count({}, scope)
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
        RailsAdmin::Config::Actions.register(self)

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :route_fragment do
          ''
        end

        register_instance_option :breadcrumb_parent do
          parent_model = bindings[:abstract_model].try(:config).try(:parent)
          if (am = parent_model && RailsAdmin.config(parent_model).try(:abstract_model))
            [:index, am]
          else
            [:dashboard]
          end
        end

        register_instance_option :controller do
          proc do
            #Patch
            if current_user || model_config.public_access?
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
            else
              redirect_to new_session_path(User)
            end
          end
        end

        register_instance_option :link_icon do
          'icon-th-list'
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
    end
  end

  class AbstractModel

    def embedded_in?(abstract_model = nil)
      embedded?
    end

    class << self

      def update_model_config(loaded_models, removed_models=[], models_to_reset=Set.new)
        loaded_models = [loaded_models] unless loaded_models.is_a?(Enumerable)
        removed_models = [removed_models] unless removed_models.is_a?(Enumerable)
        models_to_reset = [models_to_reset] unless models_to_reset.is_a?(Enumerable)
        models_to_reset = Set.new(models_to_reset) unless models_to_reset.is_a?(Set)
        collect_models(models_to_reset, models_to_reset)
        collect_models(loaded_models, models_to_reset)
        collect_models(removed_models, models_to_reset)
        models_to_reset.delete_if { |model| (dt = model.data_type).nil? || dt.to_be_destroyed }
        removed_models.each do |model|
          if model.is_a?(Class)
            Config.reset_model(model)
            Config.remove_model(model)
            if (m = all.detect { |m| m.model_name.eql?(model.to_s) })
              all.delete(m)
              puts " #{self.to_s}: model #{model.schema_name rescue model.to_s} removed!"
            else
              puts "#{self.to_s}: model #{model.schema_name rescue model.to_s} is not present to be removed!"
            end
          end
          models_to_reset.delete(model)
        end
        models_to_reset.each do |model|
          if model.is_a?(Class)
            Config.new_model(model)
            if !all.detect { |e| e.model_name.eql?(model.to_s) } && m = new(model)
              all << m
            end
          end
        end
        reset_models(models_to_reset.select { |model| model.is_a?(Class) })
      end

      def remove_model(models)
        update_model_config([], models)
      end

      def model_loaded(models)
        update_model_config(models)
      end

      def reset_models(models)
        models = [models] unless models.is_a?(Enumerable)
        models = sort_by_embeds(models)
        models.each do |model|
          puts "#{self.to_s}: resetting configuration of #{model.schema_name rescue model.to_s}"
          Config.reset_model(model)
          rails_admin_model = Config.model(model).target
          data_type = model.data_type
          data_type.reload
          schema = model.schema
          model_data_type = data_type.model.eql?(model) ? data_type : nil
          title = (model_data_type && model_data_type.title) || model.title
          { navigation_label: nil,
            visible: false,
            label: title }.each do |option, value|
            if model_data_type && model_data_type.respond_to?(option)
              value = model_data_type.send(option)
            end
            rails_admin_model.register_instance_option option do
              value
            end
          end
          if properties = schema['properties']
            properties['created_at'] = properties['updated_at'] = { 'type' => 'string', 'format' => 'date-time', 'visible' => false }
            properties.each do |property, property_schema|
              if field =
                if (property_model = model.property_model(property)).is_a?(Mongoff::Model) &&
                  !%w(integer number string boolean).include?(property_model.schema['type'])
                  rails_admin_model.field(property, :json_value)
                else
                  begin
                    rails_admin_model.fields(property.to_sym).first
                  rescue
                    rails_admin_model.field(property.to_sym)
                  end
                end
                property_schema = data_type.merge_schema(property_schema)
                visible_ok = false
                { label: 'title', help: 'description', visible: 'visible' }.each do |option, key|
                  unless (value = property_schema[key]).nil?
                    field.register_instance_option option do
                      value
                    end
                    visible_ok = true if option == :visible
                  end
                end
                unless visible_ok
                  field.register_instance_option :visible do
                    true
                  end
                end
                if field.name == :_id
                  field.register_instance_option :read_only do
                    !bindings[:object].new_record?
                  end
                  field.register_instance_option :partial do
                    'form_field'
                  end
                  field.register_instance_option :html_attributes do
                    { size: 50 }
                  end
                end
              end
            end
          end
        end
      end

      private

      def sort_by_embeds(models, sorted = [])
        models.each do |model|
          [:embeds_one, :embeds_many].each do |rk|
            sort_by_embeds(model.reflect_on_all_associations(rk).collect { |r| r.klass }.reject { |model| models.include?(model) || sorted.include?(model) }, sorted)
          end if model.is_a?(Class)
          sorted << model unless sorted.include?(model)
        end
        sorted
      end

      def collect_models(models, to_reset)
        models.each do |model|
          unless to_reset.detect { |m| m.model_access_name == model.model_access_name }
            begin
              unless model.is_a?(Class)
                affected_models = model.affected_models
              else
                to_reset << model
                [:embeds_one, :embeds_many, :embedded_in].each do |rk|
                  collect_models(model.reflect_on_all_associations(rk).collect { |r| r.klass }, to_reset)
                end
                # referenced relations must be reset if a referenced relation reflects back
                referenced_to_reset = []
                { [:belongs_to] => [:has_one, :has_many],
                  [:has_one, :has_many] => [:belongs_to],
                  [:has_and_belongs_to_many] => [:has_and_belongs_to_many] }.each do |rks, rkbacks|
                  rks.each do |rk|
                    model.reflect_on_all_associations(rk).each do |r|
                      rkbacks.each do |rkback|
                        referenced_to_reset << r.klass if r.klass.reflect_on_all_associations(rkback).detect { |r| r.klass.eql?(model) }
                      end
                    end
                  end
                end
                collect_models(referenced_to_reset, to_reset)
                affected_models = model.affected_models
              end
              collect_models(affected_models, to_reset)
            rescue Exception => ex
              puts "#{self.to_s}: error loading configuration of model #{model.schema_name rescue model.to_s} -> #{ex.message}"
            end
          end
        end
      end

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
      model_config = abstract_model.try(:config)
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
      link_to url_for(action: index_action.action_name, model_name: abstract_model.to_param, controller: 'rails_admin/main') do
        html = '<i class="icon-tasks" title="Tasks" rel="tooltip"/></i>'
        #...
        html.html_safe
      end
    end

    def authorizations_link
      _, abstract_model, index_action = linking(Setup::Authorization)
      return nil unless index_action
      link_to url_for(action: index_action.action_name, model_name: abstract_model.to_param, controller: 'rails_admin/main') do
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
      link_to url_for(action: index_action.action_name, model_name: abstract_model.to_param, controller: 'rails_admin/main') do
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
      current_user =
        if (current_account = Account.current) && current_account.super_admin? && current_account.tenant_account
          account_abstract_model = (account_config = RailsAdmin.config(Account)).abstract_model
          inspect_action = RailsAdmin::Config::Actions.find(:inspect, controller: controller, abstract_model: account_abstract_model, object: current_account.tenant_account)
          inspecting = inspect_action.try(:authorized?)
          current_account.tenant_account.owner
        else
          _current_user
        end
      abstract_model = (user_config = RailsAdmin.config(current_user.class)).abstract_model if current_user
      edit_action = RailsAdmin::Config::Actions.find(:show, controller: controller, abstract_model: abstract_model, object: current_user) if abstract_model
      unless current_user && abstract_model && edit_action
        user_config = account_config
        abstract_model = account_abstract_model
        edit_action = inspect_action
        current_user = current_account.tenant_account || current_account
      end
      return nil unless current_user && abstract_model && edit_action
      link = link_to url_for(action: edit_action.action_name, model_name: abstract_model.to_param, id: current_user.id, controller: 'rails_admin/main') do
        html = []
        # Patch
        # text = _current_user.name
        # Patch
        text = current_user.send(user_config.object_label_method)
        html << content_tag(:span, text, style: 'padding-right:5px')
        unless inspecting
          if current_user && current_user.picture.present? && abstract_model && edit_action
            html << image_tag(current_user.picture.icon.url, alt: '')
          elsif current_user.email.present?
            html << image_tag("#{(request.ssl? ? 'https://secure' : 'http://www')}.gravatar.com/avatar/#{Digest::MD5.hexdigest current_user.email}?s=30", alt: '')
          end
        end
        html.join.html_safe
      end
      if inspecting
        link = [link]
        link << link_to(url_for(action: inspect_action.action_name, model_name: account_abstract_model.to_param, id: current_account.tenant_account.id, controller: 'rails_admin/main')) do
          '<i class="icon-eye-close" style="color: red"></i>'.html_safe
        end
      end
      link
    end


    def main_navigation
      nodes_stack = RailsAdmin::Config.visible_models(controller: controller) + #Patch
        Setup::DataType.where(show_navigation_link: true, model_loaded: false).collect { |data_type| RailsAdmin.config(data_type.records_model) }
      node_model_names = nodes_stack.collect { |c| c.abstract_model.model_name }

      i = -1
      nodes_stack.group_by(&:navigation_label).collect do |navigation_label, nodes|
        i += 1
        collapse_id = "main-collapse#{i}"

        nodes = nodes.select { |n| n.parent.nil? || !n.parent.to_s.in?(node_model_names) }
        li_stack = navigation nodes_stack, nodes, collapse_id

        label = navigation_label || t('admin.misc.navigation')
        html_id = "main-#{label.underscore.gsub(' ', '-')}"

        icon = ((opts = RailsAdmin::Config.navigation_options[label]) && opts[:icon]) || 'fa fa-cube'
        icon =
          case icon
          when Symbol
            render partial: icon.to_s
          else
            "<i class='#{icon}'></i>"
          end

        %(<div id='#{html_id}' class='panel panel-default'>
            <div class='panel-heading'>
              <a data-toggle='collapse' data-parent='#main-accordion' href='##{collapse_id}' class='panel-title collapse in collapsed'>
                <span class='nav-caret'><i class='fa fa-caret-down'></i></span>
                <span class='nav-icon'>#{icon}</i></span>
                <span class='nav-caption'>#{capitalize_first_letter label}</span>
              </a>
            </div>
            #{li_stack}
          </div>) if li_stack.present?
      end.join.html_safe
    end

    def navigation(nodes_stack, nodes, html_id)
      if not nodes.present?
        return
      end
      i = -1
      ("<div id='#{html_id}' class='nav nav-pills nav-stacked panel-collapse collapse'>" +
        nodes.collect do |node|
          i += 1
          stack_id = "#{html_id}-sub#{i}"
          model_count = node.abstract_model.model.all.count

          children = nodes_stack.select { |n| n.parent.to_s == node.abstract_model.model_name }
          if children.present?
            # level_class = ''

            # nav_icon = node.navigation_icon ? %(<i class="#{node.navigation_icon}"></i>).html_safe : ''
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
                if model_count>0
                  rc += "<span class='nav-amount'>#{model_count}</span>"
                end
                rc += "<span class='nav-caption'>#{capitalize_first_letter node.label_navigation}</span>"
                rc.html_safe
              end
            end
          end
        end.join + '</div>').html_safe
    end
  end

  class MainController

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
      redirect_to(back_or_index, notice: t('admin.flash.noaction'))
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
end
