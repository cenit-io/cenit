module Xsd
  class SimpleTypeList < BasicTag

    tag 'list'

    attr_reader :item_type

    def initialize(parent, item_type=nil)
      super(parent)
      @item_type = item_type
    end

    def when_simpleType_end(simpleType)
      @item_type = simpleType
    end

    def to_json_schema
      #{'type' =>  'array', 'items' => item_type.to_json_schema}
      {'type' => 'string'}
    end
  end
end