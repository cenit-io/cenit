require 'rails_helper'

RSpec.describe 'Slim transformation runtime' do
  {
    'Setup::PrawnTemplate' => Setup::Template,
    'Setup::HandlebarsTemplate' => Setup::Template,
    'Setup::HandlebarsConverter' => Setup::ConverterTransformation
  }.each do |type, parent|
    it "does not instantiate an old #{type} record as a supported transformation" do
      attributes = { '_id' => BSON::ObjectId.new, parent.discriminator_key => type }

      expect {
        Mongoid::Factory.from_db(parent, attributes)
      }.to raise_error(Mongoid::Errors::UnknownModel, /#{Regexp.escape(type)}/)
    end
  end

  it 'rejects a legacy Prawn export with a migration diagnostic before running it' do
    renderer = Setup::Renderer.new(style: 'pdf.prawn')

    expect(renderer.style_enum).not_to include('pdf.prawn')
    expect { renderer.run }.to raise_error(ArgumentError, /Unsupported translator style.*pdf\.prawn/)
  end

  it 'includes record identity in modern Liquid rendering' do
    source = double('source record')
    allow(source).to receive(:to_hash).with(include_id: true).and_return('id' => 'lead-1', 'name' => 'Avery')
    template = Setup::LiquidTemplate.new

    expect(template.execute(code: '{{ id }}:{{ name }}', source: source)).to eq('lead-1:Avery')
  end

  it 'keeps legacy Liquid records readable and executable without injecting an id' do
    source = double('source record')
    allow(source).to receive(:to_hash).with(no_args).and_return('name' => 'Avery')
    renderer = Setup::Renderer.new(style: 'liquid', code: '{{ id }}:{{ name }}')

    expect(renderer.run(source: source)).to eq(':Avery')
  end

  it 'constructs equivalent targets for modern and legacy Liquid conversion' do
    target = double('target record')
    data_type = double('target data type')
    expect(data_type).to receive(:new_from).with('{"name":"Avery"}').twice.and_return(target)
    options = { code: '{"name":"{{ source.name }}"}', source: { 'name' => 'Avery' }, target_data_type: data_type }

    modern = options.dup
    legacy = options.dup
    Setup::LiquidConverter.new.execute(modern)
    Setup::Transformation::LiquidConversionTransform.run(legacy)

    expect(modern[:target]).to eq(target)
    expect(legacy[:target]).to eq(target)
  end
end
