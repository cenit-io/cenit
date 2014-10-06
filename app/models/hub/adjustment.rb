module Hub
  class Adjustment < Hub::Base
    field :name, type: String
    field :value, type: String

    embedded_in :order, class_name: 'Hub::Order'
    embedded_in :cart, class_name: 'Hub::Cart'

    validates_presence_of :name, :value

  end
end
