require 'cenit_cmd/collection'

module Cenit
  class Actions
    class << self

      def pull_request(shared_collection, options = {})

        pull_parameters = options[:pull_parameters] || {}
        missing_parameters = []
        shared_collection.pull_parameters.each { |pull_parameter| missing_parameters << pull_parameter.id.to_s unless pull_parameters[pull_parameter.id.to_s].present? }
        updated_records = Hash.new { |h, k| h[k] = [] }
        pull_data = shared_collection.data_with(pull_parameters)
        invariant_data = {}

        Setup::Collection.reflect_on_all_associations(:has_and_belongs_to_many).each do |relation|
          if data = pull_data[relation.name.to_s]
            invariant_data[relation.name.to_s] = invariant_names = Set.new
            data.each do |item|
              criteria = {name_space: item['name_space'], name: item['name']}
              criteria.delete_if { |_, value| value.nil? }
              if record = relation.klass.where(criteria).first
                if record.share_hash.eql?(item)
                  invariant_names << criteria
                else
                  updated_records[relation.name.to_s] << record
                end
                item['id'] = record.id.to_s
              end
            end
          end
        end

        libraries_id = (data = pull_data['libraries']) ? data.collect { |item| item['id'] } : []
        Setup::Library.any_in(id: libraries_id).each do |library|
          if library_data = data.detect { |item| item['name'] == library.name }
            if schemas_data = library_data['schemas']
              library.schemas.each do |schema|
                if schema_data = schemas_data.detect { |sch| sch['uri'] == schema.uri }
                  schema_data['id'] = schema.id.to_s
                end
              end
            end
            if data_types_data = library_data['data_types']
              library.data_types.each do |data_type|
                if data_type_data = data_types_data.detect { |dt| dt['name'] == data_type.name }
                  data_type_data['id'] = data_type.id.to_s
                end
              end
            end
          end
        end

        collection_data = pull_data.deep_dup

        invariant_data.each do |key, invariant_names|
          pull_data[key].delete_if do |item|
            criteria = {name_space: item['name_space'], name: item['name']}
            criteria.delete_if { |_, value| value.nil? }
            invariant_names.include?(criteria)
          end
        end

        [collection_data, pull_data, updated_records].each { |hash| hash.each_key { |key| hash.delete(key) if hash[key].empty? } }

        {
          pull_parameters: pull_parameters,
          updated_records: updated_records,
          missing_parameters: missing_parameters,
          pull_data: pull_data,
          collection_data: collection_data
        }
      end

      def pull(shared_collection, pull_request = {})
        pull_request = pull_request.with_indifferent_access
        pull_request = pull_request(shared_collection, pull_request) if pull_request[:pull_data].nil?
        errors = []
        if pull_request[:missing_parameters].blank?
          begin
            collection = Setup::Collection.new
            collection.from_json(pull_request.delete(:collection_data))
            begin
              collection.name = BSON::ObjectId.new.to_s
            end while Setup::Collection.where(name: collection.name).present?
            Cenit::Utility.bind_references(collection, skip_error_report: true)
            collection.libraries.each { |lib| lib.run_after_initialized }
            collection.libraries.each { |lib| lib.schemas.each(&:bind_includes) }
            collection.libraries.each { |lib| lib.schemas.each(&:run_after_initialized) }
            unless Cenit::Utility.save(collection, create_collector: create_collector = Set.new, saved_collector: saved = Set.new) &&
              (errors = Setup::DataTypeOptimizer.save_data_types).blank?
              collection.errors.full_messages.each { |msg| errors << msg }
              collection.errors.clear
              if Cenit::Utility.save(collection, {create_collector: create_collector}) && Setup::DataTypeOptimizer.save_data_types.blank?
                pull_request[:fixed_errors] = errors
                errors = []
              else
                saved.each do |obj|
                  if obj = obj.reload rescue nil
                    obj.delete
                  end
                end
              end
            end
            if errors.blank?
              Setup::Collection.where(name: shared_collection.name).delete
              collection.name = shared_collection.name
              collection.save
              pull_data = pull_request.delete(:pull_data)
              pull_request[:created_records] = collection.inspect_json(inspecting: :id, inspect_scope: create_collector).reject { |_, value| !value.is_a?(Enumerable) }
              pull_request[:pull_data] = pull_data
              pull_request[:collection] = {id: collection.id.to_s}
            end
          rescue Exception => ex
            errors << ex.message
          end
          pull_request[:errors] = errors unless errors.blank?
        end
        pull_request
      end

      def build_gem(shared_collection)
        data =
          {
            summary: shared_collection.summary,
            description: shared_collection.description,
            homepage: Cenit.homepage
          }.merge(shared_collection.to_hash).with_indifferent_access

        CenitCmd::Collection.new.build_gem(data)
      end

      def build_collection(source, klass)
        if source.nil? || source.is_a?(Array) # bulk share
          klass = klass.to_s.constantize unless klass.is_a?(Class)
          collection = Setup::Collection.new
          collection.send("#{klass.to_s.split('::').last.downcase.pluralize}=", source ? klass.any_in(id: source) : klass.all)
        else # simple share
          if source.is_a?(Setup::Collection)
            collection = source
          else
            collection = Setup::Collection.new(name: @object.try(:name))
            collection.send("#{source.class.to_s.split('::').last.downcase.pluralize}") << source
          end
        end
        collection.check_dependencies
        collection
      end

      def store(shared_collection)
        return false unless shared_collection.save
        if Cenit.share_on_github

        end
        if Cenit.share_on_ruby_gems

        end
        true
      end

      def data_type_schemas(source, options = {})
        schemas =
          case source
          when nil # All schemas
            Setup::Schema.all
          when Array # bulk schema ids
            Setup::Schema.any_in(id: source)
          else
            [source]
          end
        json_schemas = Hash.new { |h, k| h[k] = {} }
        schemas.each { |schema| json_schemas[schema.library.id].merge!(schema.json_schemas) }
        json_schemas
      end

      def generate_data_types(message)
        message = message.with_indifferent_access
        json_schemas = data_type_schemas(message[:source], message)
        json_schemas.each do |library_id, data_type_schemas|
          existing_data_types = Setup::DataType.any_in(library_id: library_id, name: data_type_schemas.keys)
          if existing_data_types.present?
            if message[:override_data_types].to_b
              Setup::DataType.shutdown(existing_data_types, deactivate: true)
              existing_data_types.each do |data_type|
                data_type.schema = data_type_schemas.delete(data_type.name)
                data_type.save
              end
            else
              fail "Can not override existing data types without override option: #{existing_data_types.collect(&:name).to_sentence}"
            end
          end
          if data_type_schemas.present?
            new_data_types_attributes = []
            data_type_schemas.each do |name, schema|
              data_type = Setup::SchemaDataType.new(name: name, schema: schema, library_id: library_id)
              new_data_types_attributes << data_type.attributes if data_type.validate_model
            end
            Setup::DataType.collection.insert(new_data_types_attributes)
          end
        end
      end

      def asynchronous_cenit_option(method)
        case method
        when :generate_data_types
          :asynchronous_data_type_generation
        else
          nil
        end
      end

      def expand_data_types(source, options = {})
        options = options.with_indifferent_access
        data_types =
          case source
          when nil # All schemas
            Setup::Schema.all
          when Array # bulk schema ids
            Setup::Schema.any_in(id: source)
          else
            [source]
          end
        data_types.each do |data_type|
          segments = {}
          refs = Set.new
          schema = data_type.merged_schema(ref_collector: refs)
          if schema['type'] == 'object' && properties = schema['properties']
            properties = data_type.merge_schema(properties, ref_collector: refs)
            properties.each do |property_name, property_schema|
              property_segment = nil
              property_schema = data_type.merge_schema(property_schema, ref_collector: refs)
              if property_schema['type'] == 'array' && items = property_schema['items']
                property_schema['items'] = items = data_type.merge_schema(items, ref_collector: refs)
                if (edi_opts = items['edi']) && edi_opts.has_key?('segment')
                  property_segment = edi_opts['segment']
                end
              end
              properties[property_name] = property_schema
              if (edi_opts = property_schema['edi']) && edi_opts.has_key?('segment')
                property_segment = edi_opts['segment']
              end
              segments[property_segment] = property_name if property_segment
            end
            schema['properties'] = properties
          end
          #TODO inject refs dependencies
          (schema['edi'] ||= {})['segments'] = segments if options[:segment_shortcuts]
          if data_type.schema != schema
            data_type.schema = schema
            data_type.save
          end
        end
      end
    end
  end
end