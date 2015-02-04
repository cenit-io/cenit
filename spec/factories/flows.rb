FactoryGirl.define do
  factory :flow_add_product, class: Setup::Flow do
    name 'Add Product'
    purpose 'send'
    active true
    
    association(:event, factory: :product_created)
    association(:webhook, factory: :webhook_add_product)
    association(:connection_role, factory: :connection_role_seller)
    # asociation{ :data_type, factory: :product_data_type}
  end
  
  factory :flow_update_product, class: Setup::Flow do
    name 'Update Product'
    purpose 'send'
    active true

    association(:event, factory: :product_updated)
    association(:webhook, factory: :webhook_update_product)
    association(:connection_role, factory: :connection_role_seller)    
    # asociation{ :data_type, factory: :product_data_type}
  end
end
