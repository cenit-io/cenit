class TaskToken < Cenit::BasicToken
  include Cenit::TenantToken
  include ::RailsAdmin::Models::TaskTokenAdmin

  belongs_to :user, class_name: Cenit::MultiTenancy.user_model_name, inverse_of: nil
  belongs_to :task, class_name: Setup::Task.to_s, inverse_of: nil
end
