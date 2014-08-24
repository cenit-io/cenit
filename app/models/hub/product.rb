module Hub
  class Product
    include Mongoid::Document
    include Mongoid::Timestamps

    field :id, type: String
    field :name, type: String
    field :sku, type: String
    field :description, type: String
    field :price, type: Float
    field :cost_price, type: Float
    field :available_on, type: Date
    field :permalink, type: String
    field :meta_description, type: String
    field :meta_keywords, type: String
    field :shipping_category, type: String
    field :options, type: Array
    field :taxons, type: Array
    field :properties, type: Hash

    embeds_many :variants, class_name: 'Hub::Variant'
    embeds_many :images, class_name: 'Hub::Image'

    accepts_nested_attributes_for :variants
    accepts_nested_attributes_for :images

    validates_presence_of :id, :name, :price, :available_on, :shipping_category
    validates_numericality_of :price, { greater_than: 0 }

  end
end
