FactoryGirl.define do
  factory :product_schema, class:  Setup::Schema do
    uri 'Product'

    schema do
      base_path = File.join(Rails.root, 'lib', 'jsons')
      file_schema = Dir.entries(base_path).select { |f| f == 'product.json' }.first
      File.read("#{base_path}/#{file_schema}")
    end

    after(:create) do |schema|
      schema.data_types.each do |data_type|
        data_type.create_default_events
      end
    end

  end
end
