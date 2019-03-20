FactoryGirl.define do
  factory :role_seller_connection, class: Setup::ConnectionRole do
    connections {[FactoryGirl.create(:store_i_connection)]}
    webhooks {[FactoryGirl.create(:add_product_webhook), FactoryGirl.create(:update_product_webhook) ]}
  end

  factory :role_buyer_connection, class: Setup::ConnectionRole do
  end
end
