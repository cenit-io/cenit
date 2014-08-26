module Hub
  class Dimension
    include Mongoid::Document
    include Mongoid::Timestamps

    field :height, type: Integer
    field :width, type: Integer

    embedded_in :image, class_name: 'Hub::Image'

  end
end
