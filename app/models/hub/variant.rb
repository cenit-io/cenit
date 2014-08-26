module Hub
  class Variant
    include Mongoid::Document
    include Mongoid::Timestamps

    field :sku, type: String
    field :price, type: Float
    field :cost_price, type: Float
    field :quantity, type: Integer
    field :options, type: Hash

    embedded_in :product, class_name: 'Hub::Product'
    embeds_many :images, class_name: 'Hub::Image'

    accepts_nested_attributes_for :images

    validates_presence_of :sku
    validates_uniqueness_of :sku

  end
end
