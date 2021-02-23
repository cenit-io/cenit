require 'objspace'

module Cenit
  class Utility

    class Proxy

      def initialize(obj, attributes = {})
        @obj = obj
        @attributes = attributes
      end

      def method(sym)
        @obj.method(sym)
      end

      def method_missing(symbol, *args, &block)
        if @attributes.has_key?(symbol)
          @attributes[symbol]
        elsif @obj.respond_to?(symbol)
          @obj.send(symbol, *args, &block)
        else
          super
        end
      end

      def respond_to?(*args)
        @attributes.has_key?(args[0]) || @obj.respond_to?(*args) || super
      end
    end

    class << self
      def save(record, options = {})
        saved = options[:saved_collector] || Set.new
        if bind_references(record, options.delete(:bind_references))
          success =
            if record.try(:save_self_before_refs)
              record.save(options) && save_references(record, options, saved)
            else
              save_references(record, options, saved) && record.save(options)
            end
          if success
            true
          else
            for_each_node_starting_at(record, stack: stack = []) do |obj|
              obj.errors.each do |attribute, error|
                attr_ref = "#{obj.orm_model.data_type.title}" +
                           ((name = obj.try(:name)) || (name = obj.try(:title)) ? " #{name} on attribute " : " property ") +
                           attribute.to_s #TODO Trunc and do html safe for long values, i.e, XML Schemas ---> + ((v = obj.try(attribute)) ? "'#{v}'" : '')
                path = ''
                stack.reverse_each do |node|
                  if !node[:record].is_a?(Mongoff::Record) && node[:referenced]
                    node[:record].errors.add(node[:attribute], "with error on #{path}#{attr_ref} (#{error})")
                  end
                  path = node[:record].orm_model.data_type.title + ' -> '
                end
              end
            end
            saved.delete_if { |obj| !obj.instance_variable_get(:@dynamically_created) }
            for_each_node_starting_at(record) do |obj|
              saved << obj if obj.instance_variable_get(:@dynamically_created)
            end
            saved.each do |obj|
              if (obj = (obj.reload rescue nil))
                obj.delete
              end
            end unless options.has_key?(:saved_collector)
            false
          end
        else
          false
        end
      end

      def bind_references(record, options = {})
        options ||= {}
        references = {}
        for_each_node_starting_at(record, options) do |obj|
          ::Setup::Optimizer.instance.regist_data_types(obj)
          if (record_refs = obj.instance_variable_get(:@_references)).present?
            references[obj] = record_refs
          end
        end

        visited = options[:visited]
        bound_records = []

        lazy_models = [Setup::MappingConverter]

        while_modifying references do
          while_modifying references do
            references.each do |obj_waiting, to_bind|
              next if lazy_models.include?(obj_waiting.class)
              visited.each do |obj|
                to_bind.each do |property_name, property_binds|
                  is_array = property_binds.is_a?(Array) ? true : (property_binds = [property_binds]; false)
                  property_binds.each do |property_bind|
                    if obj.is_a?(property_bind[:model]) && match?(obj, property_bind[:criteria])
                      if is_array
                        unless (array_property = obj_waiting.send(property_name))
                          obj_waiting.send("#{property_name}=", array_property = [])
                        end
                        array_property << obj
                      else
                        obj_waiting.send("#{property_name}=", obj)
                      end
                      property_binds.delete(property_bind)
                    end
                    to_bind.delete(property_name) if property_binds.empty?
                  end
                  if to_bind.empty?
                    bound_records << obj_waiting
                    references.delete(obj_waiting)
                  end
                end
              end
            end
          end

          references.each do |obj, to_bind|
            next if lazy_models.include?(obj.class)
            to_bind.each do |property_name, property_binds|
              is_array = property_binds.is_a?(Array) ? true : (property_binds = [property_binds]; false)
              property_binds.each do |property_bind|
                if (value = Cenit::Utility.find_record(property_bind[:criteria], obj.orm_model.property_model(property_name)))
                  if is_array
                    unless (association = obj.send(property_name)).include?(value)
                      association << value
                    end
                  else
                    obj.send("#{property_name}=", value)
                  end
                  property_binds.delete(property_bind)
                elsif !options[:skip_error_report]
                  message = "#{property_bind[:model]} reference not found with criteria #{property_bind[:criteria].to_json}"
                  obj.errors.add(property_name, message)
                  # TODO Report errors to parents
                  # message = "#{obj.class} on attribute #{property_name} #{message}"
                  # stack.reverse_each do |node|
                  #   message = "#{node[:record].class} '#{node[:record].name}' on attribute #{node[:attribute]} -> #{message}"
                  #   node[:record].errors.add(node[:attribute], message)
                  # end
                end
              end
              to_bind.delete(property_name) if property_binds.empty?
            end
            if to_bind.empty?
              bound_records << obj
              references.delete(obj)
            end
          end

          do_it = nil


          if bound_records.empty?
            if lazy_models.present?
              lazy_models.shift
              do_it = :again
            end
          else
            bound_records.each do |record|
              visited.delete(record)
              for_each_node_starting_at(record, options) do |obj|
                if (record_refs = obj.instance_variable_get(:@_references)).present?
                  references[obj] = record_refs
                end
              end
            end
            bound_records.clear
            do_it = :again
          end

          do_it
        end
        options.delete(:visited)
        record.errors.blank?
      end

      def while_modifying(hash)
        do_it = nil
        start_size = hash.size + 1
        while do_it == :again || (hash.present? && hash.size < start_size)
          start_size = hash.size
          do_it = yield
        end
      end

      def match?(obj, criteria)
        criteria.each do |property_name, value|
          property_value =
            case obj
              when Hash
                obj[property_name]
              else
                obj.try(property_name)
            end
          if value.is_a?(Hash)
            return false unless match?(property_value, value)
          else
            property_value =
              case property_value
                when BSON::ObjectId
                  value = value.to_s
                  property_value.to_s
                else
                  property_value
              end
            return false unless property_value == value
          end
        end
        true
      end

      def for_each_node_starting_at(record, options = {}, &block)
        stack = options[:stack]
        unless (visited = options[:visited])
          visited = options[:visited] = Set.new
        end
        visited << record
        block.yield(record) if block
        if (orm_model = record.try(:orm_model))
          stored_properties = orm_model.stored_properties_on(record)
          orm_model.for_each_association do |relation|
            next unless stored_properties.include?(relation[:name].to_s)
            if (values = record.send(relation[:name]))
              stack << { record: record, attribute: relation[:name], referenced: !relation[:embedded] } if stack
              values = [values] unless values.is_a?(Enumerable)
              values.each do |value|
                next if visited.include?(value)
                if (if_opt = options[:if])
                  next unless if_opt.call(value)
                end
                for_each_node_starting_at(value, options, &block)
              end
              stack.pop if stack
            end
          end
        end
      end

      def save_references(record, options, saved, visited = Set.new)
        return true if visited.include?(record)
        visited << record
        if record.is_a?(Setup::Collection)
          Setup::Collection::COLLECTING_PROPERTIES.each do |property|
            record.send(property).each do |value|
              next unless visited.exclude?(value) && value.changed?
              new_record = value.new_record?
              if value.save(options)
                if new_record || value.instance_variable_get(:@dynamically_created)
                  value.instance_variable_set(:@dynamically_created, true)
                  options[:create_collector] << value if options[:create_collector]
                else
                  options[:update_collector] << value if options[:update_collector]
                end
                saved << value
              else
                return false
              end
            end
          end
        elsif (model = record.try(:orm_model))
          model.for_each_association do |relation|
            next if Setup::BuildInDataType::EXCLUDED_RELATIONS.include?(relation[:name].to_s)
            if (values = record.send(relation[:name]))
              values = [values] unless values.is_a?(Enumerable)
              values_to_save = []
              values.each do |value|
                unless visited.include?(value)
                  return false unless save_references(value, options, saved, visited)
                  values_to_save << value
                end
              end
              values_to_save.each do |value|
                unless saved.include?(value)
                  new_record = value.new_record?
                  if value.changed?
                    if value.save(options)
                      if new_record || value.instance_variable_get(:@dynamically_created)
                        value.instance_variable_set(:@dynamically_created, true)
                        options[:create_collector] << value if options[:create_collector]
                      else
                        options[:update_collector] << value if options[:update_collector]
                      end
                      saved << value
                    else
                      return false
                    end
                    saved << value
                  end
                end
              end unless relation[:embedded]
            end
          end
        end
        true
      end

      def find_record(conditions, *scopes)
        scopes.each do |original_scope|
          scope = original_scope
          match_conditions = {}
          begin
            scope_klass =
              begin
                scope.klass
              rescue
                scope.model
              end
            scope_associations = scope_klass.get_associations
          rescue
            scope_klass = nil
            scope_associations = nil
          end
          conditions.each do |key, value|
            if value.is_a?(Hash)
              if scope_associations && (association = scope_associations[key])
                scope = scope.where(association.foreign_key => { '$in' => associated_ids(association, value) })
              else
                match_conditions[key] = value
              end
            elsif scope.respond_to?(:where)
              scope = scope.where(key => value)
            else
              scope = scope.select do |record|
                if (record_model = record.try(:orm_model))
                  record[key] == record_model.mongo_value(value, key)
                else
                  record[key] == value
                end
              end
            end
          end
          record =
            if scope.respond_to?(:detect)
              scope
            elsif scope.respond_to?(:all)
              scope.all
            else
              []
            end.detect { |record| match?(record, match_conditions) }
          if record
            if original_scope.is_a?(Enumerable) && (o_r = original_scope.detect { |item| item == record })
              return o_r
            end
            return record
          end
        end
        nil
      end

      def associated_ids(association, criteria)
        associations =
          begin
            association.klass.get_associations
          rescue
            nil
          end
        new_criteria = {}
        criteria.each do |key, value|
          if (a = associations[key])
            criteria.delete(key)
            a_criteria =
              if a == association
                value
              else
                { key => value }
              end
            new_criteria[a.foreign_key] = { '$in' => associated_ids(a, a_criteria) }
          end
        end if associations
        criteria.merge!(new_criteria)
        association.klass.where(criteria).collect(&:id)
      end

      def deep_remove(hash, key)
        if hash.is_a?(Hash)
          hash.inject({}) do |h, (k, v)|
            h[k] = deep_remove(v, key) unless k == key
            h
          end
        else
          hash
        end
      end

      def stringfy(obj)
        if obj.is_a?(Hash)
          hash = {}
          obj.each { |key, value| hash[key.to_s] = stringfy(value) }
          hash
        elsif obj.is_a?(Array)
          obj.collect { |value| stringfy(value) }
        else
          obj.is_a?(Symbol) ? obj.to_s : obj
        end
      end

      def json_object?(obj, options = {})
        case obj
          when Hash
            if options[:recursive]
              obj.keys.each { |k| return false unless k.is_a?(String) }
              obj.values.each { |v| return false unless json_object?(v) }
            end
            true
          when Array
            obj.each { |v| return false unless json_object?(v) } if options[:recursive]
            true
          else
            [Integer, BigDecimal, Float, String, TrueClass, FalseClass, Boolean, NilClass, BSON::ObjectId, BSON::Binary].any? { |klass| obj.is_a?(klass) }
        end
      end

      def array_hash_merge(val1, val2, options = {}, &block)
        if val1.is_a?(Array) && val2.is_a?(Array)
          if options[:array_uniq]
            (val2 + val1).uniq(&block)
          else
            val1 + val2
          end
        elsif val1.is_a?(Hash) && val2.is_a?(Hash)
          val1.deep_merge(val2) { |_, val1, val2| array_hash_merge(val1, val2) }
        else
          val2
        end
      end

      # TODO Remove this methods (used by rails_admin custom fields) since blank string are actually valid JSON values
      def json_value_of(value)
        return value unless value.is_a?(String)
        value = value.strip
        if value.blank?
          nil
        elsif value.start_with?('"') && value.end_with?('"')
          value[1..value.length - 2]
        else
          begin
            JSON.parse(value)
          rescue
            if (v = value.to_i).to_s == value
              v
            elsif (v = value.to_f).to_s == value
              v
            else
              case value
                when 'true'
                  true
                when 'false'
                  false
                else
                  value
              end
            end
          end
        end
      end

      def eql_content?(a, b, key = nil, &block)
        case a
          when Hash
            if b.is_a?(Hash)
              if a.size < b.size
                a, b = b, a
              end
              a.each do |k, value|
                return false unless b.key?(k) && eql_content?(value, b[k], k, &block)
              end
            else
              return block && block.call(*(block.arity == 3 ? [a, b, key] : [a, b]))
            end
          when Array
            if b.is_a?(Array) && a.length == b.length
              a = a.dup
              b = b.dup
              until a.empty?
                a_value = a.shift
                b_len = b.length
                b.delete_if { |b_value| eql_content?(a_value, b_value, &block) }
                if b.length < b_len
                  a.delete_if { |value| eql_content?(a_value, value, &block) }
                end
                return false unless a.length == b.length
              end
            else
              return block && block.call(*(block.arity == 3 ? [a, b, key] : [a, b]))
            end
          else
            return a.eql?(b) || (block && block.call(*(block.arity == 3 ? [a, b, key] : [a, b])))
        end
        true
      end
    end
  end
end
