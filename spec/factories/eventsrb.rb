# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :product_created, class: Setup::Event do
  end
  
  factory :product_updated, class: Setup::Event do
  end
end
