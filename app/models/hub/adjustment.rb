module Hub
  class Adjustment
    include Mongoid::Document
    include Mongoid::Timestamps

    field :name, type: String
    field :value, type: String

    embedded_in :order, class_name: 'Hub::Order'

    validates_presence_of :name, :value

  end
end
