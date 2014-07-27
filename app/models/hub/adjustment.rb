module Hub
  class Adjustment
    include Mongoid::Document
    include Mongoid::Attributes::Dynamic
    include Mongoid::Timestamps

    embedded_in :order, class_name: 'Hub::Order'

    field :name, type: String
    field :value, type: String

    validates_presence_of :name, :value

  end
end
