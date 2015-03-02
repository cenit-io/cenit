module Mongoid
  module CenitExtension
    extend ActiveSupport::Concern

    module ClassMethods

      def collection_size(scale=1024)
        mongo_session.command(collstats: collection_name, scale: scale)['size'] rescue 0
      end

      def for_property(property)
        (relation = try(:reflect_on_association, property)) && relation.try(:klass)
      end

      def for_each_association(&block)
        if associations = try(:reflect_on_all_associations,
                              :embeds_one,
                              :embeds_many,
                              :has_one,
                              :has_many,
                              :has_and_belongs_to_many,
                              :belongs_to)
          associations.each do |relation|
            block.yield(name: relation.name, embedded: relation.embedded?)
          end
        end
      end
    end
  end
end