module Setup
  class PropertyLocation
    include CenitUnscoped
    include HashField
    include ::RailsAdmin::Models::Setup::PropertyLocationAdmin

    build_in_data_type.referenced_by(:property_name, :location)

    field :property_name, type: String
    hash_field :location

    embedded_in :pull_parameter, class_name: Setup::CrossCollectionPullParameter.to_s, inverse_of: :properties_locations

    validates_presence_of :location, :property_name
  end
end
