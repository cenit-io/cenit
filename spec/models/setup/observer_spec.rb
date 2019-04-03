require 'spec_helper'

describe Setup::Observer do

  TEST_NAMESPACE = 'Observer Test'

  A_JSON_SAMPLE = {
    id: 1,
    name: 'A',
    number: 10,
    svalues: ["betty", "mary", "rose"],
    ovalues: [
        {
            "a": 1,
            "b": 1,
            "c": 2
        },
        {
            "a": 3,
            "b": 12,
            "c": 25
        }
    ]
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
          },
          number: {
              type: 'integer'
          },
          "svalues": {
              "type": "array",
              "items": {
                  "type": "string"
              }
          },
          "ovalues": {
              "type": "array",
              "items": {
                  "type": "object"
              }
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

  context '$size operator' do

    it 'applies with to array with three elements' do
      subject.conditions = {
          svalues: {
              '$size': 3
          }
      }
      record_a.svalues = ["juana", "maria", "antonia"]
      expect(subject.triggers_apply_to?(record_a)).to be(true)
    end

    it 'does not apply with to array with three elements' do
      subject.conditions = {
          svalues: {
              '$size': 5
          }
      }
      record_a.svalues = ["betty", "mary", "rose"]
      expect(subject.triggers_apply_to?(record_a)).to be(false)
    end
  end

  context '$regex operator' do

    it 'applies' do
      subject.conditions = {
          name: {
              '$regex': "like"
          }
      }
      record_a.name = "He likes cats"
      expect(subject.triggers_apply_to?(record_a)).to be(true)
    end

    it 'does not apply' do
      subject.conditions = {
          name: {
              '$regex': "like"
          }
      }
      record_a.name = "George"
      expect(subject.triggers_apply_to?(record_a)).to be(false)
    end
  end

  context '$elemMatch operator' do

    it 'applies' do
      subject.conditions = {
          ovalues: {
              '$elemMatch': {b:1, c: 2}
          }
      }
      record_a.ovalues = [
          {
              "a": 1,
              "b": 1,
              "c": 2
          },
          {
              "a": 3,
              "b": 12,
              "c": 25
          }
      ]
      expect(subject.triggers_apply_to?(record_a)).to be(true)
    end

    it 'does not apply' do
      subject.conditions = {
          ovalues: {
              '$elemMatch': {b:1, c: 2}
          }
      }
      record_a.ovalues = [
          {
              "a": 1,
              "b": 2,
              "c": 3
          },
          {
              "a": 3,
              "b": 12,
              "c": 25
          }
      ]
      expect(subject.triggers_apply_to?(record_a)).to be(false)
    end
  end

  context '$all operator' do

    it 'applies' do
      subject.conditions = {
          svalues: {
              '$all': ["betty", "mary", "rose"]
          }
      }
      record_a.svalues = ["betty", "mary", "rose", "katy"]
      expect(subject.triggers_apply_to?(record_a)).to be(true)
    end

    it 'does not apply' do
      subject.conditions = {
          svalues: {
              '$all': ["betty", "mary", "rose"]
          }
      }
      record_a.name = ["betty", "mary"]
      expect(subject.triggers_apply_to?(record_a)).to be(false)
    end
  end

  context '$mod operator' do

    it 'applies' do
      subject.conditions = {
          number: {
              '$mod': [10, 1]
          }
      }
      record_a.number = 11
      expect(subject.triggers_apply_to?(record_a)).to be(true)
    end

    it 'does not apply' do
      subject.conditions = {
          number: {
              '$mod': [10, 1]
          }
      }
      record_a.number = 12
      expect(subject.triggers_apply_to?(record_a)).to be(false)
    end
  end

  context '$eq operator' do

    it 'applies' do
      subject.conditions = {
          number: {
              '$eq': 10
          }
      }
      record_a.number = 10
      expect(subject.triggers_apply_to?(record_a)).to be(true)
    end

    it 'does not apply' do
      subject.conditions = {
          number: {
              '$eq': 10
          }
      }
      record_a.number = 12
      expect(subject.triggers_apply_to?(record_a)).to be(false)
    end
  end

  context '$ne operator' do
    it 'applies' do
      subject.conditions = {
          number: {
              '$ne': 10
          }
      }
      record_a.number = 12
      expect(subject.triggers_apply_to?(record_a)).to be(true)
    end

    it 'does not apply' do
      subject.conditions = {
          number: {
              '$ne': 10
          }
      }
      record_a.number = 10
      expect(subject.triggers_apply_to?(record_a)).to be(false)
    end
  end

  context '$gt operator' do

    it 'applies' do
      subject.conditions = {
          number: {
              '$gt': 10
          }
      }
      record_a.number = 12
      expect(subject.triggers_apply_to?(record_a)).to be(true)
    end

    it 'does not apply' do
      subject.conditions = {
          number: {
              '$gt': 10
          }
      }
      record_a.number = 9
      expect(subject.triggers_apply_to?(record_a)).to be(false)
    end
  end

  context '$gte operator' do

    it 'applies' do
      subject.conditions = {
          number: {
              '$gte': 10
          }
      }
      record_a.number = 10
      expect(subject.triggers_apply_to?(record_a)).to be(true)
    end

    it 'does not apply' do
      subject.conditions = {
          number: {
              '$gte': 10
          }
      }
      record_a.number = 9
      expect(subject.triggers_apply_to?(record_a)).to be(false)
    end
  end

  context '$lt operator' do

    it 'applies' do
      subject.conditions = {
          number: {
              '$lt': 10
          }
      }
      record_a.number = 9
      expect(subject.triggers_apply_to?(record_a)).to be(true)
    end

    it 'does not apply' do
      subject.conditions = {
          number: {
              '$lt': 10
          }
      }
      record_a.number = 12
      expect(subject.triggers_apply_to?(record_a)).to be(false)
    end
  end

  context '$lte operator' do

    it 'applies' do
      subject.conditions = {
          number: {
              '$lte': 10
          }
      }
      record_a.number = 10
      expect(subject.triggers_apply_to?(record_a)).to be(true)
    end

    it 'does not apply' do
      subject.conditions = {
          number: {
              '$lte': 10
          }
      }
      record_a.number = 12
      expect(subject.triggers_apply_to?(record_a)).to be(false)
    end
  end

  context '$in operator' do

    it 'applies' do
      subject.conditions = {
          number: {
              '$in': [10, 15, 21]
          }
      }
      record_a.number = 10
      expect(subject.triggers_apply_to?(record_a)).to be(true)
    end

    it 'does not apply' do
      subject.conditions = {
          number: {
              '$in': [10, 15, 21]
          }
      }
      record_a.number = 12
      expect(subject.triggers_apply_to?(record_a)).to be(false)
    end
  end

  context '$nin operator' do

    it 'applies' do
      subject.conditions = {
          number: {
              '$in': [10, 15, 21]
          }
      }
      record_a.number = 12
      expect(subject.triggers_apply_to?(record_a)).to be(true)
    end

    it 'does not apply' do
      subject.conditions = {
          number: {
              '$in': [10, 15, 21]
          }
      }
      record_a.number = 10
      expect(subject.triggers_apply_to?(record_a)).to be(false)
    end
  end
end