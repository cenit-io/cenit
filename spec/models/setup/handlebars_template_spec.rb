require 'rails_helper'

describe Setup::HandlebarsTemplate do

  test_namespace = 'Handlebars Template Test'

  simple_test_name = 'Simple Test'
  bulk_test_name = 'Bulk Test'

  before :all do
    Setup::HandlebarsTemplate.create!(
      namespace: test_namespace,
      name: simple_test_name,
      code: "Hello {{first_name}} {{last_name}}!"
    )

    Setup::HandlebarsTemplate.create!(
      namespace: test_namespace,
      name: bulk_test_name,
      bulk_source: true,
      code: "{{#each sources as |source|}}[{{source.first_name}} {{source.last_name}}]{{/each}}"
    )
  end

  let! :simple_test do
    Setup::HandlebarsTemplate.where(namespace: test_namespace, name: simple_test_name).first
  end

  let! :simple_source do
    Setup::JsonDataType.new(
      namespace: test_namespace,
      name: 'Simple Source',
      schema: {
        type: 'object',
        properties: {
          first_name: {
            type: 'string'
          },
          last_name: {
            type: 'string'
          }
        }
      }
    ).new_from(first_name: 'CENIT', last_name: 'IO')
  end

  let! :bulk_test do
    Setup::HandlebarsTemplate.where(namespace: test_namespace, name: bulk_test_name).first
  end

  let! :bulk_source do
    dt = Setup::JsonDataType.new(
      namespace: test_namespace,
      name: 'Simple Source',
      schema: {
        type: 'object',
        properties: {
          first_name: {
            type: 'string'
          },
          last_name: {
            type: 'string'
          }
        }
      }
    )

    [
      dt.new_from(first_name: 'Albert', last_name: 'Einstein'),
      dt.new_from(first_name: 'Pablo', last_name: 'Picasso'),
      dt.new_from(first_name: 'Aretha', last_name: 'Franklin'),
      dt.new_from(first_name: 'CENIT', last_name: 'IO')
    ]
  end

  context "simple source template" do

    it "renders handlebar template" do
      result = simple_test.run(source: simple_source)

      expect(result).to eq('Hello CENIT IO!')
    end
  end

  context "bulk source template" do

    it "renders handlebar template" do
      result = bulk_test.run(sources: bulk_source)

      expected = bulk_source.map do |source|
        "[#{source.first_name} #{source.last_name}]"
      end.join('')

      expect(result).to eq(expected)
    end
  end
end
