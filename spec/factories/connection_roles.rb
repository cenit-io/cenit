FactoryGirl.define do
  factory :connection_role_seller, class: Setup::ConnectionRole do
    connections {[FactoryGirl.create(:connection_store_i)]}
    webhooks {[FactoryGirl.create(:webhook_add_product), FactoryGirl.create(:webhook_update_product) ]}
  end
  
  factory :connection_role_buyer, class: Setup::ConnectionRole do

  end
end
