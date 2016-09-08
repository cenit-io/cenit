class TaskToken < Cenit::BasicToken
  include Cenit::TenantToken

  belongs_to :task, class_name: Setup::Task.to_s, inverse_of: nil
end