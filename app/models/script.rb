class Script
  include Setup::CenitUnscoped

  build_in_data_type.and(properties: {
    code: {
      contentMediaType: 'text/x-ruby'
    }
  })

  deny :all

  field :name, type: String
  field :description, type: String
  field :code, type: String

  validates_presence_of :name, :description

  before_save do
    errors.add(:code, "can't be blank") if code.blank?
    abort_if_has_errors
  end

  def parameters
    []
  end

  def run(task)
    task.instance_eval(code)
  end
end
