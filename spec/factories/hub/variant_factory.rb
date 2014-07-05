# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define  do

  factory :variant, class: Hub::Variant do
    sku "SPREE-T-SHIRT-S"
    price 39.99
    cost_price 22.33
    quantity 1
  end
  
end


