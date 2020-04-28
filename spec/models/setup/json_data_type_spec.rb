require 'rails_helper'

describe Setup::JsonDataType do

  test_namespace = 'JSON Data Type Test'

  schema_a = {
    type: 'object',
    properties: {
      name: {
        type: 'string',
        unique: true
      },
      b_nested: {
        '$ref': 'B'
      },
      b_ref: {
        referenced: true,
        '$ref': 'B'
      }
    }
  }

  schema_b = {
    type: 'object',
    properties: {
      name: {
        type: 'string',
        unique: true
      },
    }
  }

  before :all do
    Setup::JsonDataType.create!(
      namespace: test_namespace,
      name: 'B',
      schema: schema_b
    )
    Setup::JsonDataType.create!(
      namespace: test_namespace,
      name: 'A',
      schema: schema_a
    )
  end

  let! :data_type_a do
    Setup::DataType.where(namespace: test_namespace, name: 'A').first
  end

  let! :data_type_b do
    Setup::DataType.where(namespace: test_namespace, name: 'B').first
  end

  let :a_indexed_properties do
    data_type_a.records_model.collection.indexes.collect { |index| index['key'].keys.first }
  end

  let :b_indexed_properties do
    data_type_b.records_model.collection.indexes.collect { |index| index['key'].keys.first }
  end

  context "after created" do
    it 'creates a data base index for each unique property' do
      expect(b_indexed_properties).to eq(data_type_b.unique_properties)
      expect(a_indexed_properties).to eq(data_type_a.unique_properties)
    end
  end

  context "when updated" do
    it 'updates data base indexes to map unique properties' do
      data_type_b.update!(schema: schema_b.merge(properties: { name: { type: 'string', unique: false } }))
      data_type_a.update!(schema: schema_a.merge(properties: { name: { type: 'string', unique: false } }))

      expect(b_indexed_properties).to eq(data_type_b.unique_properties)
      expect(a_indexed_properties).to eq(data_type_a.unique_properties)
    end
  end
end
