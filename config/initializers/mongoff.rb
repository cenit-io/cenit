require Rails.root.join('app', 'models', 'setup', 'common_parser.rb').to_s
require Rails.root.join('app', 'models', 'setup', 'instance_model_parser.rb').to_s
require 'mongoff/model'

Mongoff::Model.config do
  base_schema do
    {
      type: 'object',
      properties: {
        created_at: {
          type: 'string',
          format: 'date-time',
          edi: {
            discard: true
          }
        },
        updated_at: {
          type: 'string',
          format: 'date-time',
          edi: {
            discard: true
          }
        },
        _type: {
          type: 'string',
          edi: {
            discard: true
          },
          visible: false
        }
      }
    }.deep_stringify_keys
  end
end
