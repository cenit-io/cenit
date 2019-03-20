require 'spec_helper'

describe Mongoff::Record do
  TEST_NAMESPACE = 'Mongoff Test'

  B_JSON_SAMPLE = {
    a_nested: {
      name: 'A'
    },
    a_nested_many: [
      { name: 'A1' },
      { name: 'A2' },
      { name: 'A3' }
    ],
    a_ref: {
      name: 'AR'
    },
    a_ref_loaded: {
      _reference: true,
      loaded: true
    },
    a_ref_many: [
      {
        _reference: true,
        loaded: true
      },
      { name: 'AR2' },
      { name: 'AR3' }
    ]
  }

  A_JSON_SAMPLE = {
    name: 'A',
    b_nested: B_JSON_SAMPLE.merge(name: 'B'),
    b_nested_many: [
      B_JSON_SAMPLE.merge(name: 'B1'),
      B_JSON_SAMPLE.merge(name: 'B2'),
      B_JSON_SAMPLE.merge(name: 'B3')
    ],
    b_ref: B_JSON_SAMPLE.merge(name: 'BR'),
    b_ref_loaded: {
      _reference: true,
      loaded: true
    },
    b_ref_many: [
      {
        _reference: true,
        loaded: true
      },
      B_JSON_SAMPLE.merge(name: 'BR2'),
      B_JSON_SAMPLE.merge(name: 'BR3')
    ]
  }

  before :all do
    data_type_a = Setup::JsonDataType.create(
      namespace: TEST_NAMESPACE,
      name: 'A',
      schema: {
        type: 'object',
        properties: {
          name: {
            type: 'string'
          },
          loaded: {
            type: 'boolean'
          },
          b_nested: {
            '$ref': 'B'
          },
          b_nested_many: {
            type: 'array',
            items: {
              '$ref': 'B'
            }
          },
          b_ref: {
            referenced: true,
            '$ref': 'B'
          },
          b_ref_loaded: {
            referenced: true,
            '$ref': 'B'
          },
          b_ref_many: {
            referenced: true,
            type: 'array',
            items: {
              '$ref': 'B'
            }
          }
        }
      }
    )

    data_type_b = Setup::JsonDataType.create(
      namespace: TEST_NAMESPACE,
      name: 'B',
      schema: {
        type: 'object',
        properties: {
          name: {
            type: 'string'
          },
          loaded: {
            type: 'boolean'
          },
          a_nested: {
            '$ref': 'A'
          },
          a_nested_many: {
            type: 'array',
            items: {
              '$ref': 'A'
            }
          },
          a_ref: {
            referenced: true,
            '$ref': 'A'
          },
          a_ref_loaded: {
            referenced: true,
            '$ref': 'A'
          },
          a_ref_many: {
            referenced: true,
            type: 'array',
            items: {
              '$ref': 'A'
            }
          }
        }
      }
    )

    a_loaded = data_type_a.create_from(loaded: true)
    b_loaded = data_type_b.create_from(loaded: true)

    data_type_a.create_from(A_JSON_SAMPLE.merge(id: a_loaded.id, loaded: true))

    data_type_b.create_from(B_JSON_SAMPLE.merge(id: b_loaded.id, loaded: true))
  end

  let! :data_type_a do
    Setup::DataType.where(namespace: TEST_NAMESPACE, name: 'A').first
  end

  let! :data_type_b do
    Setup::DataType.where(namespace: TEST_NAMESPACE, name: 'B').first
  end

  let :new_record_a do
    data_type_a.new_from(A_JSON_SAMPLE)
  end

  let :create_record_a do
    data_type_a.create_from(A_JSON_SAMPLE)
  end

  let :load_record_a do
    data_type_a.where(name: 'A').first
  end

  context 'when initialized' do
    it 'sets new_record flag to true when initialized' do
      a = new_record_a
      expect(a.new_record?).to eq(true)
    end

    it 'sets new_record flag to true on nested relations when initialized' do
      a = new_record_a
      expect(a.b_nested.new_record?).to eq(true)
    end

    it 'sets new_record flag to true on deep nested relations when initialized' do
      a = new_record_a

      flags =
        [
          a.b_nested.a_nested.new_record?,
          a.b_ref.a_nested.new_record?
        ] +
        a.b_nested_many.collect { |b| b.a_nested.new_record? } +
        a.b_ref_many.collect { |b| b.loaded || b.a_nested.new_record? }

      expect(flags).to all(eq true)
    end

    it 'sets new_record flag to true on nested many relations when initialized' do
      a = new_record_a
      flags = a.b_nested_many.collect(&:new_record?)
      expect(flags).to all(eq true)
    end

    it 'sets new_record flag to true on deep nested many relations when initialized' do
      a = new_record_a

      flags =
        a.b_nested.a_nested_many.collect(&:new_record?) +
        a.b_ref.a_nested_many.collect(&:new_record?) +
        a.b_nested_many.collect { |b| b.a_nested_many.collect(&:new_record?) }.flatten +
        a.b_ref_many.collect { |b| b.loaded || b.a_nested_many.collect(&:new_record?) }.flatten

      expect(flags).to all(eq true)
    end

    it 'sets new_record flag to true on new referenced relations when initialized' do
      a = new_record_a
      expect(a.b_ref.new_record?).to eq(true)
    end

    it 'sets new_record flag to true on deep referenced relations when initialized' do
      a = new_record_a

      flags =
        [
          a.b_nested.a_ref.new_record?,
          a.b_ref.a_ref.new_record?
        ] +
        a.b_nested_many.collect { |b| b.a_ref.new_record? } +
        a.b_ref_many.collect { |b| b.loaded || b.a_ref.new_record? }

      expect(flags).to all(eq true)
    end

    it 'sets new_record flag to false on loaded referenced relations when initialized' do
      a = new_record_a
      expect(a.b_ref_loaded.new_record?).to eq(false)
    end

    it 'sets new_record flag to false on deep loaded referenced relations when initialized' do
      a = new_record_a

      flags =
        [
          a.b_nested.a_ref_loaded.new_record?,
          a.b_ref.a_ref_loaded.new_record?
        ] +
        a.b_nested_many.collect { |b| b.a_ref_loaded.new_record? } +
        a.b_ref_many.collect { |b| b.a_ref_loaded.new_record? }

      expect(flags).to all(eq false)
    end

    it 'sets new_record flag to false on loaded records inside referenced many relations when initialized' do
      a = new_record_a
      b_loaded = a.b_ref_many.detect(&:loaded)
      expect(b_loaded.new_record?).to be(false)
    end

    it 'sets new_record flag to false on loaded records inside deep referenced many relations when initialized' do
      a = new_record_a

      flags =
        [
          a.b_nested.a_ref_many.detect(&:loaded).new_record?,
          a.b_ref.a_ref_many.detect(&:loaded).new_record?
        ] +
        a.b_nested_many.collect { |b| b.a_ref_many.detect(&:loaded).new_record? } +
        a.b_ref_many.collect { |b| b.a_ref_many.detect(&:loaded).new_record? }

      expect(flags).to all(eq false)
    end
  end

  context 'when persisted' do
    it 'sets new_record flag to false when persisted' do
      a = new_record_a
      a.save
      expect(a.new_record?).to eq(false)
    end

    it 'sets new_record flag to false on nested relations when persisted' do
      a = new_record_a
      a.save
      expect(a.b_nested.new_record?).to eq(false)
    end

    it 'sets new_record flag to false on nested many relations when persisted' do
      a = new_record_a
      a.save
      flags = a.b_nested_many.collect(&:new_record?)
      expect(flags).to all(eq false)
    end

    it 'keeps new_record flag on referenced relations when persisted' do
      a = new_record_a
      flag_before = a.b_ref.new_record?
      a.save
      expect(a.b_ref.new_record?).to eq(flag_before)
    end

    it 'keeps new_record flag on referenced many relations when persisted' do
      a = new_record_a
      flags_before = a.b_ref_many.collect(&:new_record?)
      a.save
      flags_after = a.b_ref_many.collect(&:new_record?)
      expect(flags_before).to match_array(flags_after)
    end
  end

  context 'when created' do
    it 'sets new_record flag to false when created' do
      a = create_record_a
      expect(a.new_record?).to eq(false)
    end

    it 'sets new_record flag to false on nested relations when created' do
      a = create_record_a
      expect(a.b_nested.new_record?).to eq(false)
    end

    it 'sets new_record flag to false on nested many relations when created' do
      a = create_record_a
      flags = a.b_nested_many.collect(&:new_record?)
      expect(flags).to match_array(Array.new(flags.count, false))
    end

    it 'sets new_record flag to false on referenced many relations when created' do
      a = create_record_a
      flags = a.b_ref_many.collect(&:new_record?)
      expect(flags).to all(eq false)
    end

    it 'sets new_record flag to false on deep relations when created' do
      a = create_record_a

      flags = []

      Cenit::Utility.for_each_node_starting_at(a) do |record|
        flags << record.new_record?
      end

      expect(flags).to all(eq false)
    end
  end

  context 'when loaded' do
    it 'sets new_record flag to false when loaded' do
      a = load_record_a
      expect(a.new_record?).to eq(false)
    end

    it 'sets new_record flag to false on nested relations when loaded' do
      a = load_record_a
      expect(a.b_nested.new_record?).to eq(false)
    end

    it 'sets new_record flag to false on nested many relations when loaded' do
      a = load_record_a
      flags = a.b_nested_many.collect(&:new_record?)
      expect(flags).to all(eq false)
    end

    it 'sets new_record flag to false on deep relations when loaded' do
      a = load_record_a

      flags = []

      Cenit::Utility.for_each_node_starting_at(a) do |record|
        flags << record.new_record?
      end

      expect(flags).to all(eq false)
    end
  end
end