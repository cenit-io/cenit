require 'mongoff/model'

Mongoff::Model.config do

  base_schema do
    {
      'type' => 'object',
      'properties' => {
        'created_at' => {
          'type' => 'string',
          'format' => 'date-time'
        },
        'updated_at' => {
          'type' => 'string',
          'format' => 'date-time'
        }
      }
    }
  end

  before_save ->(record) do
    record.updated_at = DateTime.now
    record.created_at = record.updated_at if record.new_record?

    record.instance_variable_set(:@_obj_before, record.orm_model.where(id: record.id).first)
  end

  after_save ->(record) do
    if record.instance_variable_get(:@discard_event_lookup)
      puts "EVENTS DISCARDED"
    else
      Setup::Observer.lookup(record, record.instance_variable_get(:@_obj_before))
    end
  end
end