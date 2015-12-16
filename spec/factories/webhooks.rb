FactoryGirl.define do
  factory :add_product_webhook, class: Setup::Webhook do
    name 'Add Product'
    path 'add_product'
    data_type { Setup::SchemaDataType.where(name: 'Product').first }

    # ensure product_schema and product_data_type will be created
    before(:create) { create(:product_schema) if Setup::Schema.where(uri: 'Product').count == 0 }
  end

  factory :update_product_webhook, class: Setup::Webhook do
    name 'Update Product'
    path 'update_product'
    data_type { Setup::SchemaDataType.where(name: 'Product').first }

    # ensure product_schema and product_data_type will be created
    before(:create) { create(:product_schema) if Setup::Schema.where(uri: 'Product').count == 0 }
  end
end
