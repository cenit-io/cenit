module Xsd
  class SimpleTypeList < BasicTag

    tag 'list'

    attr_reader :item_type

    def initialize(args)
      super
      @item_type = args[:item_type]
    end

    def when_simpleType_end(simpleType)
      @item_type = simpleType
    end

    def to_json_schema
      items_schema =
        if item_type.nil?
          {
            'anyOf' => [
              { 'type' => 'string' },
              { 'type' => 'integer' },
              { 'type' => 'number' },
              { 'type' => 'boolean' }
            ]
          }
        else
          qualify_type(item_type).to_json_schema
        end
      documenting('type' => 'array',
                  'items' => items_schema,
                  'xml' => { 'simple_type' => true }) #XML formaters should format the array into a xml simple type list format
    end
  end
end