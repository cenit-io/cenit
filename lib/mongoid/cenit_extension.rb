require 'cenit/liquidfier'

module Mongoid
  module Config
    def unregist_model(klass)
      LOCK.synchronize do
        models.delete(klass)
      end
    end
  end

  module CenitDocument
    extend ActiveSupport::Concern

    include Document

    def save(options = {})
      instance_variable_set(:@discard_event_lookup, true) if options && options[:discard_events]
      super
    rescue Exception => ex
      report = Setup::SystemReport.create_from(ex)
      errors.add(:base, report.message)
      false
    end

    def abort_if_has_errors
      throw(:abort) unless errors.blank?
      true
    end
  end

  module CenitExtension
    extend ActiveSupport::Concern

    include Setup::ClassModelParser
    include Cenit::Liquidfier

    module ClassMethods
      include Mongoff::MetadataAccess
      include Mongoff::PrettyErrors

      def mongo_value(value, field, schema = nil, &success_block)
        if field && (property_model = property_model(field)).is_a?(Mongoff::Model)
          value = property_model.mongo_value(value, property_model.schema)
        end
        if success_block
          args =
            case success_block.arity
              when 0
                []
              when 1
                [value]
              else
                [value, success_type]
            end
          success_block.call(*args)
        end
        value
      end

      def observable?
        persistable?
      end

      def modelable?
        true
      end

      def persistable?
        [Object, Setup].include?(module_parent)
      end

      def all_collections_names
        [collection_name]
      end

      def storage_size(scale = 1)
        subtype_count = data_type.subtype? && data_type.count
        data_type.all_data_type_storage_collections_names.inject(0) do |size, name|
          s =
            begin
              stats = mongo_client.command(collstats: name.to_s, scale: scale).first
              if subtype_count
                subtype_count + stats['avgObjSize']
              else
                stats['size']
              end
            rescue
              0
            end
          size + s
        end
      end

      def property_model?(property)
        ((((relation = try(:reflect_on_association, property)) && relation.try(:klass) && true) || (@mongoff_models && @mongoff_models[property].modelable?)) && true) ||
          superclass != Object && superclass.property_model?(property)
      end

      def property_model(property)
        ((relation = try(:reflect_on_association, property)) && relation.try(:klass)) ||
          (@mongoff_models && @mongoff_models[property]) ||
          (superclass.is_a?(Mongoid::Document) && superclass.property_model(property)) || nil
      end

      def stored_properties_on(record)
        properties = Set.new
        begin
          data_type.schema['properties'].keys.each do |key|
            properties << key unless record[key].nil? && record.try(key).nil?
          end
        rescue
          properties.clear
          fields.keys.each { |field| properties << field.to_s if property?(field) && !record[field].nil? }
          reflect_on_all_associations(:embeds_one,
                                      :embeds_many,
                                      :has_one,
                                      :has_many,
                                      :has_and_belongs_to_many,
                                      :belongs_to).each do |relation|
            properties << relation.name.to_s if property?(relation.name.to_s) && record.send(relation.name).present?
          end
        end
        properties
      end

      def for_each_association(&block)
        reflect_on_all_associations(:embeds_one,
                                    :embeds_many,
                                    :has_one,
                                    :has_many,
                                    :has_and_belongs_to_many,
                                    :belongs_to).each do |relation|
          unless relation.macro == :belongs_to && relation.inverse_of.present?
            block.yield(
              name: relation.name,
              embedded: relation.embedded?,
              many: relation.many?)
          end
        end
      end

      def attribute_key(field, field_metadata = {})
        if (association = reflect_on_association(field))
          association.foreign_key
        else
          field.to_s == 'id' ? :_id : field.to_sym
        end
      end

      def property_for_attribute(name)
        if property?(name)
          name
        else
          match = name.to_s.match(/\A(.+)(_id(s)?)\Z/)
          name = match && "#{match[1]}#{match[3]}"
          if property?(name)
            name
          else
            nil
          end
        end
      end

      def associations
        relations
      end
    end
  end
end