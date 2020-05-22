require 'spec_helper'

describe Mongoff::GridFs::File do

  test_namespace = 'Mongoff GridFS Test'

  before :all do
    Setup::FileDataType.create!(
      namespace: test_namespace,
      name: 'File'
    )
  end

  let! :file_data_type do
    Setup::DataType.where(namespace: test_namespace, name: 'File').first
  end

  let! :file_model do
    Setup::DataType.where(namespace: test_namespace, name: 'File').first.records_model
  end

  let! :small_data do
    '1234567890'
  end

  let! :long_data do
    '1234567890' * 100 * 1000 * 10
  end

  let! :very_long_data do
    '1234567890' * 100 * 1000 * 100
  end

  context 'when initialized' do


    it 'sets new_record flag to true when initialized' do
      file = file_model.new
      expect(file.new_record?).to eq(true)
    end

    it 'returns nil length if no data is supplied' do
      file = file_model.new
      expect(file.length).to eq(nil)
    end

    it 'returns length if data is supplied' do
      files_lengths = [
        file_model.new(data: small_data),
        file_model.new(data: long_data),
        file_model.new(data: very_long_data)
      ].map(&:length)

      data_lengths = [
        small_data,
        long_data,
        very_long_data
      ].map(&:length)

      expect(files_lengths).to eq(data_lengths)
    end

    it 'returns the supplied data if read' do
      files_data = [
        file_model.new(data: small_data),
        file_model.new(data: long_data),
        file_model.new(data: very_long_data)
      ].map(&:read)

      data = [
        small_data,
        long_data,
        very_long_data
      ]

      expect(files_data).to eq(data)
    end
  end

  context 'when persisted' do

    it 'sets new_record flag to false' do
      file = file_model.new(data: small_data)
      file.save
      expect(file.new_record?).to eq(false)
    end

    it 'returns the supplied data if read' do
      files = [
        file_model.new(data: small_data),
        file_model.new(data: long_data),
        file_model.new(data: very_long_data)
      ]
      files.each(&:save!)
      files_data = files.map(&:read)

      data = [
        small_data,
        long_data,
        very_long_data
      ]

      expect(files_data).to eq(data)
    end
  end

  context 'when created' do

    it 'sets new_record flag to false' do
      file = file_data_type.create_from!(small_data)
      expect(file.new_record?).to eq(false)
    end

    it 'returns the supplied data if read' do
      files_data = [
        file_data_type.create_from!(small_data),
        file_data_type.create_from!(long_data),
        file_data_type.create_from!(very_long_data)
      ].map(&:read)

      data = [
        small_data,
        long_data,
        very_long_data
      ]

      expect(files_data).to eq(data)
    end
  end

  context 'when loaded' do

    it 'sets new_record flag to false' do
      id = file_data_type.create_from!(small_data).id
      file = file_data_type.where(id: id).first
      expect(file.new_record?).to eq(false)
    end

    it 'returns the supplied data if read' do
      ids = [
        file_data_type.create_from!(small_data),
        file_data_type.create_from!(long_data),
        file_data_type.create_from!(very_long_data)
      ].map(&:id)

      files = ids.map do |id|
        file_data_type.where(id: id).first
      end

      data = [
        small_data,
        long_data,
        very_long_data
      ]

      expect(files.map(&:read)).to eq(data)
      expect(files.map(&:length)).to eq(data.map(&:length))
    end
  end

  context 'when updated' do

    it 'correctly updates data' do
      ids = [
        file_data_type.create_from!(small_data),
        file_data_type.create_from!(long_data),
        file_data_type.create_from!(very_long_data)
      ].map(&:id)

      files = ids.map do |id|
        file_data_type.where(id: id).first
      end

      new_data = [long_data, very_long_data, small_data]

      files.each_with_index do |file, index|
        file.data = new_data[index]
        file.save!
      end

      new_files_data = ids.map do |id|
        file_data_type.where(id: id).first
      end.map(&:read)

      expect(new_files_data).to eq(new_data)
    end

    it 'sets a new properties values while keeping the content related ones' do
      id = file_data_type.create_from!(small_data, filename: 'data.txt').id

      file = file_data_type.where(id: id).first
      props = %w(length chunkSize md5 data).map { |p| [p, file[p]] }.to_h

      new_values = {
        filename: 'data.bin',
        contentType: 'application/octet-stream',
        aliases: ['data.dat'],
        metadata: { 'rpec' => true }
      }

      new_values.each { |prop, value| file[prop] = value }
      file.save

      props.each { |prop, value| expect(file[prop]).to eq(value) }

      new_values.each { |prop, value| expect(file[prop]).to eq(value) }
    end

    it 'discard content related properties' do
      id = file_data_type.create_from!(small_data, filename: 'data.txt').id

      file = file_data_type.where(id: id).first
      props = %w(length chunkSize md5).map { |p| [p, file[p]] }.to_h
      file.length = 2 * (1 + file.length)
      file.chunkSize = 2 * (1 + file.chunkSize)
      file.md5 = "#{file.md5}-#{file.md5}"
      file.save

      props.each do |p, value|
        expect(file[p]).to eq(value)
      end
    end
  end
end