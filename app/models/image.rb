class Image
  include Mongoid::Document
  include Mongoid::Attributes::Dynamic
  include Mongoid::Timestamps

  embeds_one :dimensions
  embedded_in :image

  field :url, type: String
  field :position, type: String
  field :title, type: String
  #field :type, type: String

  accepts_nested_attributes_for :dimensions,  :autosave => true

  #attr_accessible :url, :position, :title, :type
  #attr_accessible :dimensions

  index({ starred: 1 })
end
