module Hub
  class Source < Hub::Base

    field :name, type: String
    field :month, type: Integer
    field :year, type: Integer
    field :cc_type, type: String
    field :last_digits, type: Integer

    embedded_in :payment, class_name: 'Hub::Payment'

    validates_presence_of :name, :cc_type

  end
end
