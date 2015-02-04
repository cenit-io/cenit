FactoryGirl.define do
  factory :connection_store_i, class: Setup::Connection do
    name 'Store I'
    url 'http://localhost:3001/cenit'
  end
  
  factory :connection_store_ii, class: Setup::Connection do
    name 'Store II'
    url 'http://localhost:3002/cenit'
  end
end
