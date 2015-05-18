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
          }
        },
        'updated_at' => {
          'type' => 'string',
          'format' => 'date-time',
          'edi' => {
            'discard' => true
          }
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
  end

  after_save ->(record) do
    Setup::Observer.lookup(record, record.instance_variable_get(:@_obj_before)) if record.orm_model.observable?
  end
end