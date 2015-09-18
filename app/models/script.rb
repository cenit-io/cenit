class Script
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name
  field :description, type: String
  field :code, type: String

  validates_presence_of :name, :description, :code

  def parameters
    []
  end

  def run(input)
    instance_eval(code)
  end
end