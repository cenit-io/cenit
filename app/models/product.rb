class Product
  include Mongoid::Document
  include Mongoid::Attributes::Dynamic
  include Mongoid::Timestamps

  #has_and_belongs_to_many :taxons
  #has_and_belongs_to_many :properties
  embeds_many :variants
  embeds_many :images

  field :_id, type: String
  field :name, type: String #, require: true
  field :sku, type: String #, require: true
  field :description, type: String #, require: true
  field :price, type: Float #, require: true
  field :cost_price, type: Float
  field :available_on, type: Date #, require: true
  field :permalinkDate, type: String
  field :meta_description, type: String
  field :meta_keywords, type: String
  field :shipping_category, type: String
  field :options, type: Array

  index({ starred: 1 })
end
