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
              if record = relation.klass.where(name: item['name']).first
                if record.share_hash.eql?(item)
                  invariant_names << item['name']
                else
                  updated_records[relation.name.to_s] << record
                end
                item['id'] = record.id.to_s
              end
            end
          end
        end

        Setup::Library.any_in(id: (data = pull_data['libraries']).collect { |item| item['id'] }).each do |library|
          if library_data = data.detect { |item| item['name'] == library.name }
            if schemas_data = library_data['schemas']
              library.schemas.each do |schema|
                if schema_data = schemas_data.detect { |sch| sch['uri'] == schema.uri }
                  schema_data['id'] = schema.id.to_s
                end
              end
            end
            if data_type_data = library_data['file_data_types']
              library.file_data_types.each do |file_data_type|
                if data_type_data = data_type_data.detect { |dt| dt['name'] == file_data_type.name }
                  data_type_data['id'] = file_data_type.id.to_s
                end
              end
            end
          end
        end

        collection_data = pull_data.deep_dup

        invariant_data.each { |key, invariant_names| pull_data[key].delete_if { |item| invariant_names.include?(item['name']) } }

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
            if Cenit::Utility.save(collection, {create_collector: create_collector = Set.new})
              Setup::Collection.where(name: shared_collection.name).delete
              collection.name = shared_collection.name
              collection.save
              pull_data = pull_request.delete(:pull_data)
              pull_request[:created_records] = collection.inspect_json(inspecting: :id, inspect_scope: create_collector).reject { |_, value| !value.is_a?(Enumerable) }
              pull_request[:pull_data] = pull_data
            else
              collection.errors.full_messages.each { |msg| errors << msg }
            end
          rescue Exception => ex
            errors << ex.message
          end
          pull_request[:errors] = errors unless errors.blank?
        end
        pull_request
      end

    end
  end
end