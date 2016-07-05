class AccountToken < CenitToken
  include AccountTokenCommon

  belongs_to :task, class_name: Setup::Task.to_s, inverse_of: nil
end