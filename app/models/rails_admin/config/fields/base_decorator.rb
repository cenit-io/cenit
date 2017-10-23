module RailsAdmin
  module Config
    module Fields
      class Base

        SHARED_READ_ONLY = Proc.new do
          read_only { (obj = bindings[:object]).creator_id != User.current.id && obj.shared? }
        end

        def shared_read_only
          instance_eval &SHARED_READ_ONLY
        end

        register_instance_option :index_pretty_value do
          pretty_value
        end

        register_instance_option :filter_type do
          type
        end

        register_instance_option :searchable_columns do
          case searchable
          when true
            [{ column: "#{abstract_model.table_name}.#{name}", type: type }]
          when false
            []
          when :all # valid only for associations
            table_name = associated_model_config.abstract_model.table_name
            associated_model_config.list.fields.collect { |f| { column: "#{table_name}.#{f.name}", type: f.type } }
          else
            [searchable].flatten.collect do |f|
              if f.is_a?(String) && f.include?('.') #  table_name.column
                table_name, column = f.split '.'
                type = nil
              elsif f.is_a?(Hash) #  <Model|table_name> => <attribute|column>
                am = f.keys.first.is_a?(Class) && AbstractModel.new(f.keys.first)
                table_name = am && am.table_name || f.keys.first
                column = f.values.first
                property = am && am.properties.detect { |p| p.name == f.values.first.to_sym }
                type = property && property.type
              else #  <attribute|column>
                am = (association? ? associated_model_config.abstract_model : abstract_model)
                table_name = am.table_name
                column = f
                property = am.properties.detect { |p| p.name == f.to_sym }
                type = property && property.type
              end
              { column: "#{table_name}.#{column}", type: (type || :string) }
            end
          end
        end
      end
    end
  end
end
