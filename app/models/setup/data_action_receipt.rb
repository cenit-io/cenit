module Setup
  # Private execution state: intentionally has no built-in business DataType or
  # dynamic CRUD surface. The account comes from Cenit's current tenant context.
  class DataActionReceipt
    include Mongoid::Document
    include AccountScoped

    def self.inbox_for_current_account(profile_id:)
      account = Account.current
      raise SecurityError, 'A current Cenit account is required.' unless account && account.persisted?
      require Rails.root.join('lib/cenit/data_action/mongo_inbox').to_s
      Cenit::DataAction::MongoInbox.new(collection: collection, account_id: account.id.to_s, profile_id: profile_id)
    end
  end
end
