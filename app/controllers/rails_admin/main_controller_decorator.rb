# rails_admin-1.0 ready
module RailsAdmin
  MainController.class_eval do
    include OverrideActionsHelper
    include RestApiHelper
    include SwaggerHelper
    include TraceHelper

    before_action :process_context

    alias_method :rails_admin_list_entries, :list_entries

    def list_entries(model_config = @model_config, auth_scope_key = :index, additional_scope = get_association_scope_from_params, pagination = !(params[:associated_collection] || params[:all] || params[:bulk_ids]))
      scope = rails_admin_list_entries(model_config, auth_scope_key, additional_scope, pagination)
      if (model = model_config.abstract_model.model).is_a?(Class)
        if model.include?(CrossOrigin::CenitDocument)
          origins = model.origins
          origins = origins.select { |origin| params["#{origin}_origin"].to_i.odd? }
          scope = scope.where(:origin.nin => origins)
        end

        if (filter_token = params[:filter_token]) &&
           (filter_token = Cenit::Token.where(token: filter_token).first) &&
           (criteria = filter_token.data && filter_token.data['criteria']).is_a?(Hash)
          scope = scope.and(criteria)
        end
      elsif (output = Setup::AlgorithmOutput.where(id: params[:algorithm_output]).first) &&
            output.data_type == model.data_type
        scope = scope.any_in(id: output.output_ids)
      end
      # Contextual record
      if get_context_record
        or_criteria = []
        model_config._fields.each do |f|
          next unless f.is_a?(RailsAdmin::Config::Fields::Types::ContextualBelongsTo) && f.association.klass == get_context_model
          or_criteria <<
            if f.include_blanks_on_collection_scope
              [
                { f.association.foreign_key => { '$exists': false } },
                { f.association.foreign_key => { '$in': [nil, get_context_id] } }
              ]
            else
              { f.association.foreign_key => get_context_id }
            end
        end
        scope = scope.or(or_criteria.flatten) unless or_criteria.empty?
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
        next if association.nested_form_safe?
        children_params = association.multiple? ? target_params[association.method_name].try(:values) : [target_params[association.method_name]].compact
        (children_params || []).each do |children_param|
          sanitize_params_for!(:nested, association.with(object: @object).associated_model_config, children_param)
        end
      end
    end

    def check_for_cancel
      return unless params[:_continue] || (params[:bulk_action] && !params[:bulk_ids] && !params[:object_ids])
      #Patch
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
        do_flash(:error, t('admin.flash.error', name: @model_config.label, action: t("admin.actions.#{@action.key}.done")), @object.errors.full_messages)
      end

      respond_to do |format|
        format.html { render whereto, status: :not_acceptable }
        format.js { render whereto, layout: false, status: :not_acceptable }
      end
    end

    def do_flash_process_result(objs)
      messages =
        if objs.is_a?(Hash)
          objs.collect do |key, value|
            "#{obj2msg(key)}: #{obj2msg(value)}"
          end
        else
          objs = [objs] unless objs.is_a?(Enumerable)
          objs.collect { |obj| obj2msg(obj) }
        end
      model_label = @model_config.label
      model_label = @model_config.label_plural if @action.bulkable?
      do_flash(:notice, t('admin.flash.processed', name: model_label, action: t("admin.actions.#{@action.key}.doing")) + ':', messages)
    end

    def obj2msg(obj, options = {})
      case obj
      when String, Symbol
        obj.to_s.to_title
      else
        amc = RailsAdmin.config(obj)
        am = amc.abstract_model
        wording = obj.send(amc.object_label_method)
        if (show_action = view_context.action(options[:action] || :show, am, obj))
          wording + ' ' + view_context.link_to("(#{options[:action_label] || t('admin.flash.click_here')})", view_context.url_for(action: show_action.action_name, model_name: am.to_param, id: obj.id), class: 'pjax')
        else
          wording
        end
      end
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
      if (count = messages.length - count).positive?
        flash_message += "<br>- and another #{count}.".html_safe
      end
      flash_hash[flash_key] = flash_message.html_safe
    end

    def get_association_scope_from_params
      return nil unless params[:associated_collection].present?
      #Patch
      if (source_abstract_model = params[:source_abstract_model]) && (source_abstract_model = RailsAdmin::AbstractModel.new(to_model_name(source_abstract_model)))
        source_model_config = source_abstract_model.config #TODO When configuring APPs or other forms rendering use the proper model config
        source_object = source_abstract_model.get(params[:source_object_id])
        action = params[:current_action].in?(%w(create update)) ? params[:current_action] : 'edit'
        if (@association = source_model_config.send(action).fields.detect { |f| f.name == params[:associated_collection].to_sym })
          @association.with(controller: self, object: source_object).associated_collection_scope
        end
      end
    end

    def process_bulk_scope
      model ||=
        begin
          @abstract_model.model
        rescue Exception
          nil
        end
      if model
        @bulk_ids = (@object && [@object.id]) || params.delete(:bulk_ids) || params.delete(:object_ids)
        if @bulk_ids.nil? && (params[:all] = true) && (scope = list_entries).count < model.count
          @bulk_ids = scope.collect(&:id).collect(&:to_s) #TODO Store scope options and selector instead ids
        end
      end
      params.delete(:query)
      model
    end

    def get_collection(model_config, scope, pagination)
      associations = model_config.list.fields.select { |f| f.type == :belongs_to_association && !f.polymorphic? }.collect { |f| f.association.name }
      options = {}
      options = options.merge(page: (params[Kaminari.config.param_name] || 1).to_i, per: (params[:per] || model_config.list.items_per_page)) if pagination
      options = options.merge(include: associations) unless associations.blank?
      options = options.merge(get_sort_hash(model_config))
      options = options.merge(query: params[:query]) if params[:query].present?
      options = options.merge(filters: params[:f]) if params[:f].present?
      options = options.merge(bulk_ids: params[:bulk_ids]) if params[:bulk_ids]
      # Patch
      options = options.merge(filter_query: params[:filter_query]) if params[:filter_query].present?
      options = options.merge(criteria: params[:c]) if params[:c].present?
      model_config.abstract_model.all(options, scope)
    end

    def redirect_to_on_success(opts = nil)
      flash = {}
      unless opts && opts[:skip_flash]
        flash = {
          success: I18n.t('admin.flash.successful', name: @model_config.label, action: I18n.t("admin.actions.#{@action.key}.done"))
        }
      end
      if params[:_add_another]
        redirect_to new_path(return_to: params[:return_to]), flash: flash
      elsif params[:_add_edit]
        redirect_to edit_path(id: @object.id, return_to: params[:return_to]), flash: flash
      else
        redirect_to back_or_index, flash: flash
      end
    end
  end
end
