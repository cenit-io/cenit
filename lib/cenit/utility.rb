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

      def method_missing(symbol, *args)
        if @attributes.has_key?(symbol)
          @attributes[symbol]
        elsif @obj.respond_to?(symbol)
          @obj.send(symbol)
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
        if bind_references(record)
          if save_references(record, options, saved) && record.save(options)
            true
          else
            for_each_node_starting_at(record, stack=[]) do |obj|
              obj.errors.each do |attribute, error|
                attr_ref = "#{obj.orm_model.data_type.title}" +
                  ((name = obj.try(:name)) || (name = obj.try(:title)) ? " #{name} on attribute " : "'s '") +
                  attribute.to_s #TODO Truck and do html safe for long values, i.e, XML Schemas ---> + ((v = obj.try(attribute)) ? "'#{v}'" : '')
                path = ''
                stack.reverse_each do |node|
                  node[:record].errors.add(node[:attribute], "with error on #{path}#{attr_ref} (#{error})") if node[:referenced]
                  path = node[:record].orm_model.data_type.title + ' -> '
                end
              end
            end
            saved.delete_if { |obj| !obj.instance_variable_get(:@dynamically_created) }
            for_each_node_starting_at(record) do |obj|
              saved << obj if obj.instance_variable_get(:@dynamically_created)
            end
            saved.each do |obj|
              if obj = obj.reload rescue nil
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
        references = {}
        for_each_node_starting_at(record) do |obj|
          if record_refs = obj.instance_variable_get(:@_references)
            references[obj] = record_refs
          end
        end
        for_each_node_starting_at(record) do |obj|
          references.each do |obj_waiting, to_bind|
            to_bind.each do |property_name, property_binds|
              is_array = property_binds.is_a?(Array) ? true : (property_binds = [property_binds]; false)
              property_binds.each do |property_bind|
                if obj.is_a?(property_bind[:model]) && match?(obj, property_bind[:criteria])
                  if is_array
                    unless array_property = obj_waiting.send(property_name)
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
              references.delete(obj_waiting) if to_bind.empty?
            end
          end
        end if references.present?

        for_each_node_starting_at(record, stack = []) do |obj|
          if to_bind = references[obj]
            to_bind.each do |property_name, property_binds|
              is_array = property_binds.is_a?(Array) ? true : (property_binds = [property_binds]; false)
              property_binds.each do |property_bind|
                if value = Cenit::Utility.find_record(obj.orm_model.property_model(property_name).all, property_bind[:criteria])
                  if is_array
                    if !(association = obj.send(property_name)).include?(value)
                      association << value
                    end
                  else
                    obj.send("#{property_name}=", value)
                  end
                elsif !options[:skip_error_report]
                  message = "reference not found with criteria #{property_bind[:criteria].to_json}"
                  obj.errors.add(property_name, message)
                  stack.each { |node| node[:record].errors.add(node[:attribute], message) }
                end
              end
            end
          end
        end if references.present?
        record.errors.blank?
      end

      def match?(obj, criteria)
        criteria.each do |property_name, value|
          if value.is_a?(Hash)
            return false unless match?(obj.try(property_name), value)
          else
            return false unless obj.try(property_name) == value
          end
        end
        true
      end

      def for_each_node_starting_at(record, stack = nil, visited = Set.new, &block)
        visited << record
        block.yield(record) if block
        if orm_model = record.try(:orm_model)
          orm_model.for_each_association do |relation|
            if values = record.send(relation[:name])
              stack << {record: record, attribute: relation[:name], referenced: !relation[:embedded]} if stack
              values = [values] unless values.is_a?(Enumerable)
              values.each { |value| for_each_node_starting_at(value, stack, visited, &block) unless visited.include?(value) }
              stack.pop if stack
            end
          end
        end
      end

      def save_references(record, options, saved, visited = Set.new)
        return true if visited.include?(record)
        visited << record
        if model = record.try(:orm_model)
          model.for_each_association do |relation|
            next if Setup::BuildInDataType::EXCLUDED_RELATIONS.include?(relation[:name].to_s)
            if values = record.send(relation[:name])
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

      def find_record(scope, conditions)
        match_conditions = {}
        conditions.each do |key, value|
          if value.is_a?(Hash)
            match_conditions[key] = value
          else
            scope = scope.where(key => value)
          end
        end
        scope.detect { |record| match?(record, match_conditions) }
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

      def memory_usage_of(model)
        return 0 unless model
        size = ObjectSpace.memsize_of(model)
        model.constants(false).each { |c| size += memory_usage_of(c) } if model.is_a?(Class) || model.is_a?(Module)
        size > 0 ? size : 100
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
          [Integer, Float, String, TrueClass, FalseClass, Boolean, NilClass, BSON::ObjectId, BSON::Binary].any? { |klass| obj.is_a?(klass) }
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

      def json_value_of(value)
        return value unless value.is_a?(String)
        if value.blank?
          nil
        elsif value.start_with?('"') && value.end_with?('"')
          value[1..value.length - 2]
        elsif v = JSON.parse(value) rescue nil
          v
        elsif value == 'true'
          true
        elsif value == 'false'
          false
        elsif (v = value.to_i).to_s == value
          v
        elsif (v = value.to_f).to_s == value
          v
        else
          value
        end
      end

      def abs_uri(base_uri, uri)
        uri = URI.parse(uri.to_s)
        return uri.to_s unless uri.relative?

        base_uri = URI.parse(base_uri.to_s)
        uri = uri.to_s.split('/')
        path = base_uri.path.split('/')
        begin
          path.pop
        end while uri[0] == '..' ? uri.shift && true : false

        path = (path + uri).join('/')

        uri = URI.parse(path)
        uri.scheme = base_uri.scheme
        uri.host = base_uri.host
        uri.to_s
      end
    end
  end
end
