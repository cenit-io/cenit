module AccountScoped
  extend ActiveSupport::Concern
  included do
    store_in collection: Proc.new { Account.tenant_collection_name(to_s) }
    def id
      self._id.to_s
    end
  end
end
