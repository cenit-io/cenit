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

      def contextualized_label(context = nil)
        label
      end

      def contextualized_label_plural(context = nil)
        label_plural
      end
    end

    module Actions

      class New
        register_instance_option :controller do
          proc do

            #Patch
            if request.get? || params[:_restart] # NEW

              @object = @abstract_model.new
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
              @abstract_models = RailsAdmin::Config.visible_models(controller: self).collect(&:abstract_model)

              @most_recent_changes = {}
              @count = {}
              @max = 0
              @abstract_models.each do |t|
                scope = @authorization_adapter && @authorization_adapter.query(:index, t)
                current_count = t.count({}, scope)
                @max = current_count > @max ? current_count : @max
                @count[t.model.name] = current_count
                next unless t.properties.detect { |c| c.name == :updated_at }
                # Patch
                # @most_recent_changes[t.model.name] = t.first(sort: "#{t.table_name}.updated_at").try(:updated_at)
              end
            end
            render @action.template_name, status: (flash[:error].present? ? :not_found : 200)
          end
        end
      end
    end

    module Fields

      class Association

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
                count += 1
                can_see = !am.embedded? && (show_action = v.action(:show, am, associated))
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
          if (v = bindings[:object].send(association.name))
            if v.is_a?(Enumerable)
              total = v.count
              v = v.limit(limit) rescue v
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
        html = '<i class="icon-tasks"/></i>'
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
      return nil unless _current_user.respond_to?(:email)
      return nil unless (abstract_model = RailsAdmin.config(_current_user.class).abstract_model)
      return nil unless (edit_action = RailsAdmin::Config::Actions.find(:show, controller: controller, abstract_model: abstract_model, object: _current_user)).try(:authorized?)
      link_to url_for(action: edit_action.action_name, model_name: abstract_model.to_param, id: _current_user.id, controller: 'rails_admin/main') do
        html = []
        if _current_user.picture.present?
          html << image_tag(_current_user.picture.icon.url, alt: '')
        elsif _current_user.email.present?
          html << image_tag("#{(request.ssl? ? 'https://secure' : 'http://www')}.gravatar.com/avatar/#{Digest::MD5.hexdigest _current_user.email}?s=30", alt: '')
        end
        # Patch
        # text = _current_user.name
        # Patch
        text = _current_user.email if text.blank?
        html << content_tag(:span, text)
        html.join.html_safe
      end
    end


    def main_navigation
      nodes_stack = RailsAdmin::Config.visible_models(controller: controller) + #Patch
        Setup::DataType.where(show_navigation_link: true, model_loaded: false).collect { |data_type| RailsAdmin.config(data_type.records_model) }
      node_model_names = nodes_stack.collect { |c| c.abstract_model.model_name }

      i = -1
      nodes_stack.group_by(&:navigation_label).collect do |navigation_label, nodes|
        nodes = nodes.select { |n| n.parent.nil? || !n.parent.to_s.in?(node_model_names) }
        li_stack = navigation nodes_stack, nodes

        label = navigation_label || t('admin.misc.navigation')

        i += 1
        %(<div class='panel panel-default'>
            <div class='panel-heading'>
              <a data-toggle='collapse' data-parent='#main-accordion' href='#main-collapse#{i}' class='panel-title collapse in'>#{capitalize_first_letter label}</a>
            </div>
            <div id='main-collapse#{i}' class='nav nav-pills nav-stacked panel-collapse collapse'>#{li_stack}
            </div>
          </div>) if li_stack.present?
      end.join.html_safe
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
          if show_action = view_context.action(:show, am, obj)
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
    end
  end

  class ApplicationController

    def get_model
      #Patch
      @model_name = to_model_name(name = params[:model_name].to_s)
      data_type = nil
      unless (@abstract_model = RailsAdmin::AbstractModel.new(@model_name))
        if (slugs = name.to_s.split('~')).size == 2
          if (library = Setup::Library.where(slug: slugs[0]).first)
            data_type = Setup::DataType.where(library: library, slug: slugs[1]).first
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
      else
        fail(RailsAdmin::ObjectNotFound)
      end
    end
  end
end
