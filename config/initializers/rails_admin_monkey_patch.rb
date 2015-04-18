require 'rails_admin/config'
require 'rails_admin/main_controller'
require 'rails_admin/config/fields/types/carrierwave'
require 'rails_admin/adapters/mongoid'

module RailsAdmin

  module Config

    class << self

      def remove_model(model)
        models_pool
        @@system_models.delete_if { |e| e.eql?(model.to_s) }
      end

      def new_model(model)
        if !models_pool.include?(model.to_s)
          @@system_models.insert((i = @@system_models.find_index { |e| e > model.to_s }) ? i : @@system_models.length, model.to_s)
        end
      end
    end

    module Actions

      class New
        register_instance_option :controller do
          proc do

            if request.get? || params[:_restart] # NEW

              @object = @abstract_model.new
              @authorization_adapter && @authorization_adapter.attributes_for(:new, @abstract_model).each do |name, value|
                @object.send("#{name}=", value)
              end
              if object_params = params[@abstract_model.to_param]
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

              if params[:_next].nil? && @object.save
                @auditing_adapter && @auditing_adapter.create_object(@object, @abstract_model, _current_user)
                respond_to do |format|
                  format.html { redirect_to_on_success }
                  format.js { render json: {id: @object.id.to_s, label: @model_config.with(object: @object).object_label} }
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

              if synchronized_fields = @model_config.try(:form_synchronized)
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
                  format.js { render json: {id: @object.id.to_s, label: @model_config.with(object: @object).object_label} }
                end
              else
                handle_save_error :edit
              end

            end

          end
        end
      end
    end
  end

  class AbstractModel
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
          Config.remove_model(model)
          if m = all.detect { |m| m.model_name.eql?(model.to_s) }
            all.delete(m)
            puts "#{self.to_s}: model #{model.schema_name rescue model.to_s} removed!"
          else
            puts "#{self.to_s}: model #{model.schema_name rescue model.to_s} is not present to be removed!"
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
          data_type = model.data_type
          data_type.reload
          schema = data_type.merged_schema
          path = model.schema_path
          path.split('/').each { |token| schema = data_type.merge_schema(schema[token]) if token.present? }
          model_data_type = data_type.model.eql?(model) ? data_type : nil
          rails_admin_model = Config.model(model).target
          title = model_data_type ? model_data_type.title : model.title
          {navigation_label: nil,
           visible: false,
           label: title}.each do |option, value|
            if model_data_type && model_data_type.respond_to?(option)
              value = model_data_type.send(option)
            end
            rails_admin_model.register_instance_option option do
              value
            end
          end
          if properties = schema['properties']
            properties.each do |property, property_schema|
              if field =
                if model.property_model(property).is_a?(Mongoff::Model)
                  rails_admin_model.field(property, :json_schema) do
                    config do
                      {
                        mode: 'css',
                        theme: 'neo',
                      }
                    end
                    assets do
                      {
                        mode: '/assets/codemirror/modes/css.js',
                        theme: '/assets/codemirror/themes/neo.css',
                      }
                    end
                  end
                else
                  rails_admin_model.fields(property.to_sym).first
                end
                property_schema = data_type.merge_schema(property_schema)
                visible_ok = false
                {label: 'title', help: 'description', visible: 'visible'}.each do |option, key|
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
                    {size: 50}
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
            sort_by_embeds(model.reflect_on_all_associations(rk).collect { |r| r.klass }, sorted)
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
                {[:belongs_to] => [:has_one, :has_many],
                 [:has_one, :has_many] => [:belongs_to],
                 [:has_and_belongs_to_many] => [:has_and_belongs_to_many]}.each do |rks, rkbacks|
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
              #raise ex
            end
          end
        end
      end
    end
  end

  class MainController
    def sanitize_params_for!(action, model_config = @model_config, target_params = params[@abstract_model.param_key])
      return unless target_params.present?
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

    def handle_save_error(whereto = :new)
      if @object && @object.errors.present?
        flash.now[:error] = t('admin.flash.error', name: @model_config.label, action: t("admin.actions.#{@action.key}.done").html_safe).html_safe
        flash.now[:error] += %(<br>- #{@object.errors.full_messages.join('<br>- ')}).html_safe
      end

      respond_to do |format|
        format.html { render whereto, status: :not_acceptable }
        format.js { render whereto, layout: false, status: :not_acceptable }
      end
    end
  end

  module Adapters
    module Mongoid

      def sort_by(options, scope)
        return scope unless options[:sort]

        case options[:sort]
        when String
          collection_name = (sort = options[:sort])[0..i = sort.rindex('.') - 1]
          field_name = sort.from(i + 2)
          if collection_name && collection_name != table_name
            fail('sorting by associated model column is not supported in Non-Relational databases')
          end
        when Symbol
          field_name = options[:sort].to_s
        end
        if options[:sort_reverse]
          scope.asc field_name
        else
          scope.desc field_name
        end
      end
    end
  end
end
