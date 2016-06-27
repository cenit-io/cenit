module Setup
  class Collection
    include CenitScoped
    include CollectionBehavior

    image_with AccountImageUploader

    unique_name


    embeds_many :data, class_name: Setup::CollectionData.to_s, inverse_of: :setup_collection

    accepts_nested_attributes_for :data, allow_destroy: true

    def before_scanning_algorithms(algorithms_collector)
      super
      data.each { |collection_data| check_data_type_dependencies(collection_data.data_type, algorithms_collector) }
    end
  end
end
