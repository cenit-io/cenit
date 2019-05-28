class RabbitConsumer
  include Mongoid::Document
  include Mongoid::Timestamps

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
      Setup::Task.with(collection: Account.tenant_collection_name(Setup::Task, tenant: executor)).where(id: task_id).first
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
end
