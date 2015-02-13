require 'rails_admin/config'

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
        models_to_reset.delete_if { |model| model.data_type.to_be_destroyed }
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
          unless model.is_a?(Hash)
            Config.new_model(model)
            if !all.detect { |e| e.model_name.eql?(model.to_s) } && m = new(model)
              all << m
            end
          end
        end
        reset_models(models_to_reset)
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
        reset = Set.new
        models.each do |model|
          puts "#{self.to_s}: resetting configuration of #{model.schema_name rescue model.to_s}"
          Config.reset_model(model)
          data_type = model.data_type
          schema = JSON.parse(data_type.schema)
          model.schema_path.split('/').each do |token|
            unless token.blank?
              schema = data_type.merge_schema(schema[token])
            end
          end
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
            rails_admin_model.groups.each do |group|
              group.fields.each do |field|
                if field_schema = properties[field.name.to_s]
                  field_schema = data_type.merge_schema(field_schema)
                  {label: 'title',
                   help: 'description'}.each do |option, key|
                    if value = field_schema[key]
                      field.register_instance_option option do
                        value
                      end
                    end
                  end
                else
                  field.register_instance_option :visible do
                    false
                  end
                end
              end
            end
          end
        end
      end

      private

      def sort_by_embeds(models, sorted=[])
        models.each do |model|
          [:embeds_one, :embeds_many].each do |rk|
            sort_by_embeds(model.reflect_on_all_associations(rk).collect { |r| r.klass }, sorted)
          end
          sorted << model unless sorted.include?(model)
        end
        sorted
      end

      def collect_models(models, to_reset)
        models.each do |model|
          unless to_reset.detect { |m| m.to_s == model.to_s }
            begin
              if (model.is_a?(Hash))
                affected_models = model[:affected] || []
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
end
