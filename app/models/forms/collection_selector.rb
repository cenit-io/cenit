module Forms
  class CollectionSelector
    include Mongoid::Document

    belongs_to :collection, class_name: Setup::Collection.to_s, inverse_of: nil

    validates_presence_of :collection_id

    rails_admin do
      visible false
      register_instance_option(:discard_submit_buttons) { true }
      edit do
        field :collection
      end
    end
  end
end
