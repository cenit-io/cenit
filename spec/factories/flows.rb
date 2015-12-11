FactoryGirl.define do
  factory :add_product_flow, class: Setup::Flow do
    name 'Add Product'
    active true

    association(:webhook, factory: :add_product_webhook)
    association(:connection_role, factory: :role_seller_connection)

    # ensure product_schema and product_data_type will be created
    before(:create) { create(:product_schema) if Setup::Schema.where(uri: 'Product').count == 0 }
    data_type { Setup::SchemaDataType.where(name: 'Product').first }
    event { Setup::Event.where(name: "Product on created_at").first }
  end

  factory :update_product_flow, class: Setup::Flow do
    name 'Update Product'
    active true

    association(:webhook, factory: :update_product_webhook)
    association(:connection_role, factory: :role_seller_connection)

    # ensure product_schema and product_data_type will be created
    before(:create) { create(:product_schema) if Setup::Schema.where(uri: 'Product').count == 0 }
    data_type { Setup::SchemaDataType.where(name: 'Product').first }
    event { Setup::Event.where(name: "Product on updated_at").first }
  end
end
