module Hub
  class Order
    include Mongoid::Document
    include Mongoid::Attributes::Dynamic
    include Mongoid::Timestamps
    #TODO: lunch error when include AfterSave when use rake sample:load
    #include Hub::AfterSave
    
    # always include the lower boundary for semi open intervals
    scope :placed_on_gte, -> (reference_time) { where('students.placed_on >= ?', reference_time) }

    # always exclude the upper boundary for semi open intervals
    scope :placed_on_lt, -> (reference_time) { where('students.placed_on < ?', reference_time) }

    scope :placed_on_between, ->(start_date, end_date) { where(placed_on: start_date..end_date) }

    belongs_to :connection, class_name: 'Setup::Connection'

    field :id, type: String
    field :status, type: String
    field :channel, type: String
    field :email, type: String
    field :currency, type: String
    field :placed_on, type: DateTime

    belongs_to :totals, class_name: 'Hub::OrderTotal'

    has_many :line_items, class_name: 'Hub::LineItem'
    embeds_many :adjustments, class_name: 'Hub::Adjustment'

    embeds_many :payments, class_name: 'Hub::Payment'

    belongs_to :shipping_address, class_name: 'Hub::Address'
    belongs_to :billing_address, class_name: 'Hub::Address'

    accepts_nested_attributes_for :totals
    accepts_nested_attributes_for :line_items
    accepts_nested_attributes_for :adjustments
    accepts_nested_attributes_for :shipping_address
    accepts_nested_attributes_for :billing_address
    accepts_nested_attributes_for :payments

    validates_presence_of :id, :status, :channel, :currency, :placed_on

  end
end
