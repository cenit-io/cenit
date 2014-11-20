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

      def remove_model(model)
        Config.remove_model(model)
        if m = all.detect { |m| m.model_name.eql?(model.to_s) }
          all.delete(m)
          puts "#{self.to_s}: model #{model.to_s} removed!"
        else
          puts "#{self.to_s}: model #{model.to_s} is not present to be removed!"
        end

      end

      def model_loaded(model, exclude_reset=[])
        return if model.nil?
        begin
          model = model.constantize if model.is_a?(String)
        rescue
          return
        end
        Config.new_model(model)
        if !all.detect { |e| e.model_name.eql?(model.to_s) } && m = new(model)
          all << m
        end
        reset_config(model, exclude_reset)
        return m
      end

      def reset_config(model, exclude_reset=[])
        unless exclude_reset.include?(model)
          begin
            model = model.constantize if model.is_a?(String)
            puts "#{self.to_s}: resetting configuration of #{model.to_s}"
            RailsAdmin::Config.reset_model(model)
            exclude_reset << model
            [:embeds_one, :embeds_many, :embedded_in].each do |rk|
              model.reflect_on_all_associations(rk).each { |r| model_loaded(r.klass, exclude_reset) }
            end
            # referenced relations only affects if a referenced relation reflects back
            {[:belongs_to] => [:has_one, :has_many], [:has_one, :has_many] => [:belongs_to], [:has_and_belongs_to_many] => [:has_and_belongs_to_many]}.each do |rks, rkbacks|
              rks.each do |rk|
                model.reflect_on_all_associations(rk).each do |r|
                  rkbacks.each do |rkback|
                    model_loaded(r.klass, exclude_reset) if r.klass.reflect_on_all_associations(rkback).detect { |r| r.klass.eql?(model) }
                  end
                end
              end
            end
            begin
              model.affected_models.each { |m| model_loaded(m, exclude_reset) }
            rescue
            end
          rescue
            puts "#{self.to_s}: could not reset model #{model.to_s}"
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

