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

      def update_model_config(loaded_models, removed_models=[], models_to_reset=[])
        models_to_reset = [models_to_reset] unless models_to_reset.is_a?(Enumerable)
        collect_models(models_to_reset, models_to_reset)
        collect_models(loaded_models, models_to_reset)
        collect_models(removed_models, models_to_reset)
        removed_models.each do |model|
          Config.remove_model(model)
          if m = all.detect { |m| m.model_name.eql?(model.to_s) }
            all.delete(m)
            puts "#{self.to_s}: model #{model.to_s} removed!"
          else
            puts "#{self.to_s}: model #{model.to_s} is not present to be removed!"
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
        update_model_config(models, [])
      end

      def reset_models(models)
        models = [models] unless models.is_a?(Enumerable)
        models = models.sort_by do |model|
          parent = model.parent
          index = 0
          while !parent.eql?(Object)
            index = index - 1
            parent = parent.parent
          end
          index
        end
        models.each do |model|
          puts "#{self.to_s}: resetting configuration of #{model.to_s}"
          Config.reset_model(model)
          data_type = Setup::DataType.find_by(id: model.data_type_id) rescue nil
          {navigation_label: nil,
           visible: false,
           label: model.to_s.split('::').last}.each do |option, default_value|
            rails_admin_model = Config.model(model).target
            rails_admin_model.register_instance_option option do
              data_type && data_type.respond_to?(option) ? data_type.send(option) : default_value
            end
          end
        end
      end

      def collect_models(models, to_reset)
        models = [models] unless models.is_a?(Enumerable)
        models.each do |model|
          unless to_reset.include?(model)
            begin
              if (model.is_a?(Hash))
                affected_models = model[:affected] || []
              else
                to_reset << model
                [:embeds_one, :embeds_many, :embedded_in].each do |rk|
                  model.reflect_on_all_associations(rk).each { |r| collect_models(r.klass, to_reset) }
                end
                # referenced relations muts be reset if a referenced relation reflects back
                {[:belongs_to] => [:has_one, :has_many],
                 [:has_one, :has_many] => [:belongs_to],
                 [:has_and_belongs_to_many] => [:has_and_belongs_to_many]}.each do |rks, rkbacks|
                  rks.each do |rk|
                    model.reflect_on_all_associations(rk).each do |r|
                      rkbacks.each do |rkback|
                        collect_models(r.klass, to_reset) if r.klass.reflect_on_all_associations(rkback).detect { |r| r.klass.eql?(model) }
                      end
                    end
                  end
                end
                affected_models = model.affected_models
              end
              begin
                affected_models.each { |m| collect_models(m, to_reset) }
              rescue
              end
            rescue Exception => ex
              puts "#{self.to_s}: error loading configuration of model #{model.to_s} -> #{ex.message}"
              raise ex
            end
          end
        end
      end
    end
  end
end

#module RailsAdmin
#  module Config
#    class << self
#      def new_model(model)
#        if !models_pool.include?(model.to_s)
#          @@system_models.insert((i = @@system_models.find_index { |e| e > model.to_s  }) ? i : @@system_models.length, model.to_s)
#        end
#      end
#    end
#  end
#  
#  class AbstractModel
#    class << self
#      def new_model(model_str_schema)
#        regist_model(Cenit::MongoDynamic.parse_str_schema(model_str_schema))
#      end
#      
#      def regist_model(model)
#        Config.new_model(model)
#        if m = new(model)
#          if i = all.find_index { |e| e.to_s.eql?(m.to_s)  }
#            @@all[i] = m
#          else
#            @@all << m
#          end
#        end
#      end
#    end
#  end
#end

