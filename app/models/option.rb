class Option
  include Mongoid::Document
  include Mongoid::Attributes::Dynamic
  include Mongoid::Timestamps

  has_and_belongs_to_many :variants

  index({ starred: 1 })
end
