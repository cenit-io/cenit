module Mongoid

  module Scopable

    private

    def apply_default_scoping
      if default_scoping
        default_scoping.call.selector.each do |field, value|
          attributes[field] = value unless field.start_with?('$') || value.respond_to?(:each_pair)
        end
      end
    end
  end

  module Contextual
    class Mongo
      def yield_document(document, &block)
        doc = document.respond_to?(:_id) ?
          document : Factory.from_db(klass, document, criteria.options[:fields])
        #Patch
        doc = doc.account_version
        yield(doc)
        documents.push(doc) if cacheable?
      end
    end
  end

  module Document

    def account_version
      self
    end
  end
end