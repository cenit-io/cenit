module RailsAdmin
  module Config
    class << self
      def new_model(model)
        unless models_pool.include?(model.to_s)
          @@system_models.insert((i = @@system_models.find_index { |e| e > model.to_s  }) ? i : @@system_models.length, model.to_s)
        end
      end
    end
  end
  
  class AbstractModel
    class << self
      def parse_model(model_str_schema, to_include=[])
        regist_model(Setup::ModelSchema.parse_str_schema(model_str_schema, to_include))        
      end
      
      def regist_model(model)
        Config.new_model(model)
        if !all.detect { |e| e.to_s.eql?(model.to_s)  } && m = new(model)
          all << m
        end
        reset_config(model)
        return m
      end
      
      def reset_config(model, excluded=[])
        unless excluded.include?(model)
          begin
            model = model.constantize if model.is_a?(String)
            puts 'Resetting configuration of ' + model.to_s
            RailsAdmin::Config.reset_model(model)
            excluded << model
            model.reflect_on_all_associations(:embedded_in).each {|r| reset_config(r.klass, excluded)}
            model.reflect_on_all_associations(:belongs_to).each {|r| reset_config(r.klass, excluded)}
            model.reflect_on_all_associations(:has_and_belongs_to_many).each {|r| reset_config(r.klass, excluded)}
          rescue
            puts 'Could not reset model ' + model.to_s
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

