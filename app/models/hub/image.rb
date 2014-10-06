module Hub
  class Image < Hub::Base

    field :url, type: String
    field :position, type: String
    field :title, type: String
    field :type, type: String

    embedded_in :variant, class_name: 'Hub::Variant'
    embedded_in :product, class_name: 'Hub::Product'
    embeds_one :dimension, class_name: 'Hub::Dimension'

    accepts_nested_attributes_for :dimension

    validates_presence_of :url

  end
end
