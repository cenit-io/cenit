require 'spec_helper'

describe Setup::Observer do

  TEST_NAMESPACE = 'Observer Test'

  A_JSON_SAMPLE = {
    id: 1,
    name: 'A'
  }

  before :all do
    data_type_a = Setup::JsonDataType.create(
      namespace: TEST_NAMESPACE,
      name: 'A',
      schema: {
        type: 'object',
        properties: {
          id: {
            type: 'integer'
          },
          name: {
            type: 'string'
          }
        }
      }
    )

    data_type_a.create_from(A_JSON_SAMPLE)
  end

  let! :data_type_a do
    Setup::DataType.where(namespace: TEST_NAMESPACE, name: 'A').first
  end

  let :record_a do
    data_type_a.where(id: A_JSON_SAMPLE[:id]).first
  end

  let :record_a_before do
    data_type_a.where(id: A_JSON_SAMPLE[:id]).first
  end

  context '$changes operator' do

    it 'applies with no before instance to compare' do
      subject.conditions = {
        name: {
          '$changes': true
        }
      }
      expect(subject.triggers_apply_to?(record_a)).to be(true)
    end

    it 'does not apply when no changes are made' do
      subject.conditions = {
        name: {
          '$changes': true
        }
      }
      expect(subject.triggers_apply_to?(record_a, record_a_before)).to be(false)
    end

    it 'applies when a change is made' do
      subject.conditions = {
        name: {
          '$changes': true
        }
      }
      record_a.name = 'A Changed'
      expect(subject.triggers_apply_to?(record_a, record_a_before)).to be(true)
    end
  end
end