FactoryGirl.define do
  factory :webhook_add_product, class: Setup::Webhook do
    name 'Add Product'
    path 'add_product'
    purpose 'send'
    #association(:data_type, factory: :product_data_type)
  end
  
  factory :webhook_update_product, class: Setup::Webhook do
    name 'Update Product'
    path 'update_product'
    purpose 'send'
    #association(:data_type, factory: :product_data_type)
  end
end
