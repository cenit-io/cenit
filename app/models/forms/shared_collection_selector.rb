module Forms
  class SharedCollectionSelector
    include Mongoid::Document

    belongs_to :shared_collection, class_name: Setup::CrossSharedCollection.to_s, inverse_of: nil

    validate do
      erros.add(:shared_collection, "can't be blank") unless shared_collection
    end

    def criteria
      @criteria ||= {}
    end

    def criteria=(criteria)
      self.shared_collection = Setup::CrossSharedCollection.where(@criteria = criteria).first
    end

    rails_admin do
      visible false
      register_instance_option(:discard_submit_buttons) { true }
      edit do
        field :shared_collection do
          inline_edit false
          inline_add false
          associated_collection_cache_all true
          associated_collection_scope do
            criteria = bindings[:object].criteria
            Proc.new { |scope| scope.where(criteria) }
          end
        end
      end
    end
  end
end
