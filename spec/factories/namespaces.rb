FactoryGirl.define do
  factory :namespaces, class: Setup::Namespace do
    sequence(:name) { |n| "Namespace#{n}" }
    sequence(:slug) { |n| "slug#{n}" }
  end
end
