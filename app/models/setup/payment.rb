module Setup
  class Payment
    include CenitUnscoped
    include RailsAdmin::Models::Setup::PaymentAdmin
    include RailsAdminDynamicCharts::Datetime

    build_in_data_type

    allow :index, :show, :simple_export, :export

    field :_id, type: String
    field :title, type: String
    field :description, type: String
    field :date, type: DateTime
    field :mount, type: Float
    field :credit, type: Float

    validates_length_of :_id, :title, maximum: 100
    validates_presence_of :_id, :title, :date, :mount, :credit
  end
end
