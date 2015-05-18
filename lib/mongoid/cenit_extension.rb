module Mongoid
  module CenitExtension
    extend ActiveSupport::Concern

    include Setup::ClassModelParser

    module ClassMethods

      include Mongoff::MetadataAccess

      def mongo_value(value, field_or_schema)
        return value unless field_or_schema.is_a?(String) || field_or_schema.is_a?(Symbol)
        if (property_model = property_model(field_or_schema)).is_a?(Mongoff::Model)
          property_model.mongo_value(value, property_model.schema)
        else
          value
        end
      end

      def observable?
        true
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
          s = mongo_session.command(collstats: name, scale: scale)['size'] rescue 0
          size + s
        end
      end

      def property_model?(property)
        ((((relation = try(:reflect_on_association, property)) && relation.try(:klass) && true) || (@mongoff_models && @mongoff_models[property].modelable?)) && true) || false
      end

      def property_model(property)
        ((relation = try(:reflect_on_association, property)) && relation.try(:klass)) || (@mongoff_models && @mongoff_models[property])
      end

      def for_each_association(&block)
        reflect_on_all_associations(:embeds_one,
                                    :embeds_many,
                                    :has_one,
                                    :has_many,
                                    :has_and_belongs_to_many,
                                    :belongs_to).each do |relation|
          block.yield(name: relation.name, embedded: relation.embedded?)
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