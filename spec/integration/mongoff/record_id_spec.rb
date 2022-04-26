require 'spec_helper'

describe Mongoff::Record do
  test_namespace = 'Mongoff Record auto ID Test'

  before :all do
    Setup::JsonDataType.create!(
      namespace: test_namespace,
      name: 'A',
      schema: {
        type: 'object',
        properties: {
          name: {
            type: 'string'
          }
        }
      }
    )

    Setup::JsonDataType.create!(
      namespace: test_namespace,
      name: 'B',
      schema: {
        type: 'object',
        properties: {
          id: {
            type: 'string',
            auto: true
          },
          name: {
            type: 'string'
          }
        }
      }
    )

    Setup::JsonDataType.create!(
      namespace: test_namespace,
      name: 'C',
      schema: {
        type: 'object',
        properties: {
          id: {
            type: 'string'
          },
          name: {
            type: 'string'
          }
        }
      }
    )
  end

  let! :data_type_a do
    Setup::DataType.where(namespace: test_namespace, name: 'A').first
  end

  let! :data_type_b do
    Setup::DataType.where(namespace: test_namespace, name: 'B').first
  end

  let! :data_type_c do
    Setup::DataType.where(namespace: test_namespace, name: 'C').first
  end

  context 'when initialized' do

    it 'generates an ID for default auto property ID' do
      a = data_type_a.new_from(name: 'A')
      expect(a.id).to be
    end

    it 'generates an ID for string auto property ID' do
      b = data_type_b.new_from(name: 'B')
      expect(b.id).to be
    end

    it 'does generates an ID for auto property ID' do
      c = data_type_c.new_from(name: 'C')
      expect(c.id).to be nil
    end
  end

  context 'when persisted' do

    it 'successfully save default auto generated IDs' do
      a = data_type_a.new_from(name: 'A')
      a.save
      expect(a.errors.blank?).to be true
    end

    it 'successfully save default auto generated IDs when supplied' do
      id = BSON::ObjectId.new
      a = data_type_a.new_from(id: id.to_s, name: 'A')
      a.save
      expect(a.errors.blank?).to be true
      expect(a.id).to eq id
    end

    it 'successfully save default auto generated IDs when supplied in bad format' do
      id = 'not a BSON Object ID'
      a = data_type_a.new_from(id: id.to_s, name: 'A')
      a.save
      expect(a.errors.blank?).to be true
      expect(a.id.class).to eq BSON::ObjectId
    end

    it 'successfully save string auto generated IDs' do
      b = data_type_b.new_from(name: 'B')
      b.save
      expect(b.errors.blank?).to be true
    end

    it 'does not save records with missing IDs' do
      c = data_type_c.new_from(name: 'B')
      c.save
      expect(c.errors[:_id]).to include('is required')
    end
  end

  context 'when created' do

    it 'generates an ID for default auto property ID' do
      a = data_type_a.create_from(name: 'A')
      expect(a.new_record?).to be false
    end

    it 'generates an ID for string auto property ID' do
      b = data_type_a.create_from(name: 'B')
      expect(b.new_record?).to be false
    end

    it 'does generates an ID for auto property ID' do
      c = data_type_c.create_from(name: 'B')
      expect(c.errors[:_id]).to include('is required')
    end
  end
end