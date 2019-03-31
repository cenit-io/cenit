FactoryGirl.define do  
  factory :user do
    email                 { FFaker::Internet.email }
    password              { 'secret1234' }
    password_confirmation { password }
  end
end
