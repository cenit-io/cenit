# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  sequence(:random_email) { FFaker::Internet.email }
  
  factory :user do
    email                 { generate(:random_email) }
    password              { 'secret1234' }
    password_confirmation { password }
  end
end
