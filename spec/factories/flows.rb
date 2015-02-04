FactoryGirl.define do
  factory :flow_add_product, class: Setup::Flow do
    name 'Add Product'
    purpose 'send'
    active true
    asociation{:event, factory: :product_created}
    asociation {:webhook, factory: :webhook_add_product}
    asociation {:connection_role, factory: :connection_role_seller}
    # asociation{ :data_type, factory: :product_data_type}
  end
  
  factory :flow_add_product, class: Setup::Flow do
    name 'Update Product'
    purpose 'send'
    active true
    asociation{:event, factory: :product_updated}
    asociation {:webhook, factory: :webhook_update_product}
    asociation {:connection_role, factory: :connection_role_seller}
    # asociation{ :data_type, factory: :product_data_type}
  end
end
