module Hub
  class Dimension < Hub::Base

    field :height, type: Integer
    field :width, type: Integer

    embedded_in :image, class_name: 'Hub::Image'

  end
end
