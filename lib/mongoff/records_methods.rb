module Mongoff
  module RecordsMethods
    extend ActiveSupport::Concern

    included do
      [:to_hash, :to_json, :to_xml, :to_xml_element, :to_edi].each do |method|
        class_eval "def #{method}(options = {})
          if orm_model.data_type.records_methods.any? { |alg| alg.name == '#{method}' }
            method_missing(:#{method}, options)
          else
            super
          end
        end"
      end
    end

    def method_missing(symbol, *args)
      if (method = orm_model.data_type.records_methods.detect { |alg| alg.name == symbol.to_s })
        args.unshift(self)
        method.reload
        method.run(args)
      else
        super
      end
    end
  end
end