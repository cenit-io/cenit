FactoryGirl.define do
  factory :store_i_connection, class: Setup::Connection do
    name 'Store I'
    url 'http://localhost:3001/cenit'
  end

  factory :store_ii_connection, class: Setup::Connection do
    name 'Store II'
    url 'http://localhost:3002/cenit'
  end
end
