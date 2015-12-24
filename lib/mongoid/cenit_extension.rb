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
      instance_variable_set(:@discard_event_lookup, true) if options[:discard_events]
      super
    end
  end

  module CenitExtension
    extend ActiveSupport::Concern

    include Setup::ClassModelParser

    module ClassMethods

      include Mongoff::MetadataAccess

      def mongo_value(value, field, schema = nil)
        return value unless field
        if (property_model = property_model(field)).is_a?(Mongoff::Model)
          property_model.mongo_value(value, property_model.schema)
        else
          value
        end
      end

      def observable?
        persistable?
      end

      def modelable?
        true
      end

      def persistable?
        [Object, Setup].include?(parent)
      end

      def all_collections_names
        [collection_name]
      end

      def storage_size(scale = 1)
        data_type.all_data_type_storage_collections_names.inject(0) do |size, name|
          s = mongo_client.command(collstats: name, scale: scale).first['size'] rescue 0
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
        fields.keys.each { |field| properties << field.to_s if property?(field) && !record[field].nil? }
        reflect_on_all_associations(:embeds_one,
                                    :embeds_many,
                                    :has_one,
                                    :has_many,
                                    :has_and_belongs_to_many,
                                    :belongs_to).each do |relation|
          properties << relation.name.to_s if property?(relation.name.to_s) && record.send(relation.name).present?
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
          block.yield(name: relation.name, embedded: relation.embedded?) unless relation.macro == :belongs_to && relation.inverse_of.present?
        end
      end

      def other_affected_models
        models = []
        reflect_on_all_associations(:embedded_in,
                                    :embeds_one,
                                    :embeds_many,
                                    :has_one,
                                    :has_many,
                                    :has_and_belongs_to_many,
                                    :belongs_to).each do |relation|
          models << relation.klass unless [:has_and_belongs_to_many, :belongs_to].include?(relation.macro) && relation.inverse_of.nil?
        end
        models.uniq
      end

      def other_affected_by
        reflect_on_all_associations(:embedded_in,
                                    :embeds_one,
                                    :embeds_many,
                                    :has_one,
                                    :has_many,
                                    :has_and_belongs_to_many,
                                    :belongs_to).collect { |relation| relation.klass }.uniq
      end
    end
  end
end