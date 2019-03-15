module Setup
  module Taggable
    extend ActiveSupport::Concern

    included do
      field :tags, type: String
    end

    module ClassMethods

      def tags_values
        distinct(:tags).flatten.collect do |tags|
          tags = JSON.parse(tags) rescue [tags.to_s]
          tags.to_a
        end.flatten.uniq
      end

    end

  end
end
