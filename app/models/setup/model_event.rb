module Setup
  class ModelEvent
    include Mongoid::Document
    include Mongoid::Timestamps

    belongs_to :model, class_name: 'Setup::ModelSchema'
  end
end