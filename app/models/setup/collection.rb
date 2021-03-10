module Setup
  class Collection
    include CenitScoped
    include CollectionBehavior
    include Taggable
    include AsynchronousPersistence::Model

    image_with AccountImageUploader

    unique_name

    belongs_to :picture, class_name: Setup::PublicStorage.to_s, inverse_of: nil

    # TODO: Include Data data types on dependencies
    embeds_many :data, class_name: Setup::CollectionData.to_s, inverse_of: :setup_collection

    accepts_nested_attributes_for :data, allow_destroy: true

    class << self

      def origins
        ([:default] + Setup::CrossSharedCollection.origins).uniq
      end
    end
  end
end
