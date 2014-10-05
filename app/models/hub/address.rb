module Hub
  class Address < Hub::Base

    field :firstname, type: String
    field :lastname, type: String
    field :address1, type: String
    field :address2, type: String, default: ''
    field :city, type: String
    field :state, type: String
    field :country, type: String
    field :phone, type: String
    field :zipcode, type: String

    embedded_in :order, class_name: 'Hub::Order'
    embedded_in :shipment, class_name: 'Hub::Shipment'
    embedded_in :customer, class_name: 'Hub::Customer'
    embedded_in :cart, class_name: 'Hub::Cart'

    validates_presence_of :firstname, :lastname, :address1, :zipcode, :city, :state, :country

  end
end
