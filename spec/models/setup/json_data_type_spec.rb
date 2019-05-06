require 'rails_helper'

describe Setup::JsonDataType do

  TEST_NAMESPACE = 'JSON Data Type Test'

  SCHEMA_A = {
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

  SCHEMA_B = {
    type: 'object',
    properties: {
      name: {
        type: 'string',
        unique: true
      },
    }
  }

  before :all do
    Setup::JsonDataType.create(
      namespace: TEST_NAMESPACE,
      name: 'B',
      schema: SCHEMA_B
    )
    Setup::JsonDataType.create(
      namespace: TEST_NAMESPACE,
      name: 'A',
      schema: SCHEMA_A
    )
  end

  let! :data_type_a do
    Setup::DataType.where(namespace: TEST_NAMESPACE, name: 'A').first
  end

  let! :data_type_b do
    Setup::DataType.where(namespace: TEST_NAMESPACE, name: 'B').first
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
      data_type_b.update(schema: SCHEMA_B.merge(properties: { name: { type: 'string', unique: false } }))
      data_type_a.update(schema: SCHEMA_A.merge(properties: { name: { type: 'string', unique: false } }))

      expect(b_indexed_properties).to eq(data_type_b.unique_properties)
      expect(a_indexed_properties).to eq(data_type_a.unique_properties)
    end
  end
end
