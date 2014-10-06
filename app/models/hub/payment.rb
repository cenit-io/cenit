module Hub
  class Payment < Hub::Base

    field :number, type: Integer
    field :status, type: String
    field :amount, type: Float
    field :payment_method, type: String

    embeds_one :source, class_name: 'Hub::Source'

    embedded_in :order, class_name: 'Hub::Order'
    embedded_in :cart, class_name: 'Hub::Cart'

    accepts_nested_attributes_for :source

    validates_presence_of :number, :status, :amount, :payment_method

  end
end
