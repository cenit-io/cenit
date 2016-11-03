require 'mongoff/model'

Mongoff::Model.config do

  base_schema do
    {
      'type' => 'object',
      'properties' => {
        'created_at' => {
          'type' => 'string',
          'format' => 'date-time',
          'edi' => {
            'discard' => true
          },
          'visible' => false
        },
        'updated_at' => {
          'type' => 'string',
          'format' => 'date-time',
          'edi' => {
            'discard' => true
          },
          'visible' => false
        },
        '_type' => {
          'type' => 'string',
          'edi' => {
            'discard' => true
          },
          'visible' => false
        }
      }
    }
  end

  before_save ->(record) do
    record.updated_at = DateTime.now
    if record.new_record?
      record.created_at = record.updated_at
    elsif record.orm_model.observable?
      record.instance_variable_set(:@_obj_before, record.orm_model.where(id: record.id).first)
    end
    true
  end

  after_save ->(record) do
    if record.orm_model.observable? && !record.instance_variable_get(:@discard_event_lookup)
      Setup::Observer.lookup(record, record.instance_variable_get(:@_obj_before))
    end
  end
end
