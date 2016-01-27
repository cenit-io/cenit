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
              criteria = {namespace: item['namespace'], name: item['name']}
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
            criteria = {namespace: item['namespace'], name: item['name']}
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
            unless Cenit::Utility.save(collection, create_collector: create_collector = Set.new, saved_collector: saved = Set.new)
              collection.errors.full_messages.each { |msg| errors << msg }
              collection.errors.clear
              if Cenit::Utility.save(collection, {create_collector: create_collector})
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
              collection.image = shared_collection.image if shared_collection.image.present?
              collection.save
              shared_collection.pull_count = 0 if shared_collection.pull_count.nil?
              shared_collection.pull_count += 1
              shared_collection.save
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
          file_name, gem = Cenit::Actions.build_gem(shared_collection)
          file = Tempfile.new(file_name)
          file.binmode
          file.write(gem)
          file.rewind


          obj = GemSynchronizer.new Cenit.github_shared_collections_home,
                                    {
                                      login: Cenit.github_shared_collections_user,
                                      password: Cenit.github_shared_collections_pass
                                    }
          begin
            obj.github_update! file
          rescue Exception => ex
            Setup::Notification.create_from(ex)
          end

          file.close
        end
        if Cenit.share_on_ruby_gems

        end
        true
      end
    end
  end
end