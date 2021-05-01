class RabbitConsumer
  include Setup::CenitUnscoped
  include Cancelable

  build_in_data_type.on_origin(:admin)

  deny :all

  field :channel, type: String
  field :tag, type: String
  field :task_id
  field :alive, type: Boolean, default: true

  belongs_to :executor, class_name: Account.to_s, inverse_of: nil

  validates_presence_of :tag
  validates_uniqueness_of :tag

  after_initialize do
    self.tag = "cenit-#{id.to_s}" unless tag.present?
  end

  before_save do
    reset_attribute!('alive') unless new_record? || changed_attributes['alive']
  end

  def executing_task
    if executor && task_id
      executor.switch { Setup::Task.where(id: task_id).first }
    end
  end

  def to_s
    tag.to_s
  end

  def cancel
    update(alive: false)
  end

  def cancelled?
    !alive
  end

  class << self

    def cancel_all(scope = all)
      scope.update_all(alive: false)
    end
  end
end
