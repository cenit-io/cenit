require 'cenit_cmd/collection'

module Cenit
  class Actions
    class << self

      def pull_request(shared_collection, options = {})

        pull_parameters = options[:pull_parameters] || {}
        missing_parameters = []
        shared_collection.pull_parameters.each { |pull_parameter| missing_parameters << pull_parameter.id.to_s unless pull_parameters[pull_parameter.id.to_s].present? }

        new_records = Hash.new { |h, k| h[k] = [] }
        updated_records = Hash.new { |h, k| h[k] = [] }

        pull_data = shared_collection.data_with(pull_parameters)

        invariant_data = {}

        collection_data = { '_reset' => resetting = [] }
        unless (collection = Setup::Collection.where(name: shared_collection.name).first) && (collection.readme == shared_collection.readme)
          collection_data['readme'] = shared_collection.readme
          resetting << 'readme'
        end

        Setup::Collection.reflect_on_all_associations(:has_and_belongs_to_many).each do |relation|
          entry = relation.name.to_s
          if (items = pull_data[entry])
            invariant_data[entry] = invariant_names = Set.new
            invariant_on_collection = 0
            items_data_type = relation.klass.data_type
            refs =
              items.collect do |item|
                criteria = {}
                items_data_type.get_referenced_by.each { |field| criteria[field.to_s] = item[field.to_s] }
                criteria.delete_if { |_, value| value.nil? }
                unless (on_collection = (record = collection && collection.send(relation.name).where(criteria).first))
                  record = relation.klass.where(criteria).first
                end
                if record
                  record_hash = Cenit::Utility.stringfy(record.share_hash)
                  if item['_type']
                    record_hash['_type'] = record.class.to_s unless record_hash['_type']
                  end
                  if Cenit::Utility.eql_content?(record_hash, item)
                    invariant_names << criteria
                    invariant_on_collection += 1 if on_collection
                    item = criteria
                    item['_reference'] = true
                  else
                    updated_records[entry] << record
                  end
                  item['id'] = record.id.to_s
                  check_embedded_items(item, relation.klass, record)
                else
                  new_records[entry] << item
                end
                item
              end
            unless (collection && collection.send(relation.name).count == invariant_on_collection) && (invariant_on_collection == items.size)
              collection_data[entry] = refs
              resetting << entry
            end
          elsif collection && collection.send(relation.name).present?
            resetting << entry
          end
        end

        if resetting.present?
          if collection
            updated_records['collections'] << collection
          else
            new_records['collections'] << { 'name' => shared_collection.name }
          end
        end

        invariant_data.each do |key, invariant_names|
          pull_data[key].delete_if do |item|
            criteria = { namespace: item['namespace'], name: item['name'] }
            criteria.delete_if { |_, value| value.nil? }
            invariant_names.include?(criteria)
          end
        end

        [collection_data, pull_data, updated_records].each { |hash| hash.each_key { |key| hash.delete(key) if hash[key].blank? } }

        {
          pull_parameters: pull_parameters,
          new_records: new_records,
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
          created_nss_ids = []
          begin
            collection_data = pull_request.delete(:collection_data)
            (collection_data['namespaces'] || []).each do |ns_hash|
              next if ns_hash.has_key?('id')
              if (ns = Setup::Namespace.create(ns_hash)).errors.blank?
                ns_hash['id'] = ns.id.to_s
                created_nss_ids << ns.id
              else
                fail "Error creating namespace for #{ns_hash.to_json}: #{ns.errors.full_messages.to_sentence}"
              end
            end
            collection = Setup::Collection.where(name: shared_collection.name).first
            attrs = (collection && collection.attributes.deep_dup) || {}
            attrs.delete('_id')
            collection = Setup::Collection.new(attrs)
            collection.from_json(collection_data, add_only: true)
            collection.events.each { |e| e[:activated] = false if e.is_a?(Setup::Scheduler) && e.new_record? }
            begin
              collection.name = BSON::ObjectId.new.to_s
            end while Setup::Collection.where(name: collection.name).present?
            unless Cenit::Utility.save(collection, bind_references: { if: ->(r) { r.instance_variable_get(:@_edi_parsed) } },
                                       create_collector: (create_collector = Set.new),
                                       saved_collector: (saved = Set.new))
              collection.errors.full_messages.each { |msg| errors << msg }
              collection.errors.clear
              if Cenit::Utility.save(collection, { create_collector: create_collector })
                pull_request[:fixed_errors] = errors
                errors = []
              else
                saved.each do |obj|
                  if (obj = (obj.reload rescue nil))
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
              shared_collection.pulling = true
              shared_collection.save
              pull_data = pull_request.delete(:pull_data)
              pull_request[:created_records] = collection.inspect_json(inspecting: :id, inspect_scope: create_collector).reject { |_, value| !value.is_a?(Enumerable) }
              pull_request[:pull_data] = pull_data
              pull_request[:collection] = { id: collection.id.to_s }
            end
          rescue Exception => ex
            errors << ex.message
          end
          unless errors.blank?
            Setup::Namespace.all.any_in(id: created_nss_ids.to_a).delete_all
            pull_request[:errors] = errors
          end
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

      private

      def check_embedded_items(item, item_model, record)
        item_model.model_properties_schemas.each do |property, schema|
          next if schema['referenced']
          next unless (property_value = item[property]) && (property_model = item_model.property_model(property))
          next unless (property_data_type = property_model.data_type).get_referenced_by.present?
          if schema['type'] == 'object'
            if (record_value = record.send(property))
              criteria = {}
              property_data_type.get_referenced_by.each { |field| criteria[field.to_s] = property_value[field.to_s] }
              criteria.delete_if { |_, value| value.nil? }
              if Cenit::Utility.match?(record_value, criteria)
                property_value['id'] = record_value.id.to_s
                check_embedded_items(property_value, property_model, record_value)
              end
            end
          elsif (association = record.send(property).to_a).present?
            property_value.each do |sub_item|
              criteria = {}
              property_data_type.get_referenced_by.each { |field| criteria[field.to_s] = sub_item[field.to_s] }
              criteria.delete_if { |_, value| value.nil? }
              if (sub_record = Cenit::Utility.find_record(criteria, association))
                sub_item['id'] = sub_record.id.to_s
                check_embedded_items(sub_item, property_model, sub_record)
              end
            end
          end
        end
      end
    end
  end
end