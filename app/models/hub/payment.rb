module Hub
  class Payment
    include Mongoid::Document
    include Mongoid::Timestamps

    field :number, type: Integer
    field :status, type: String
    field :amount, type: Float
    field :payment_method, type: String

    embedded_in :order, class_name: 'Hub::Order'
    embeds_one :source, class_name: 'Hub::Source'

    accepts_nested_attributes_for :source

    validates_presence_of :number, :status, :amount, :payment_method

  end
end
