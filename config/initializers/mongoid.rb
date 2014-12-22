module Mongoid
  module Document

    def as_json(options={})
      attrs = super(options)

      delete_fields(attrs)
      delete_deep_in(attrs)

      attrs
    end

    def delete_fields(attrs)
      ['_id', 'created_at', 'updated_at', 'images'].each do |f|
        attrs.delete(f) if attrs.has_key?(f)
      end
    end

    def delete_deep_in(attrs)
      attrs.each do |k, v|
        if v.is_a?(Hash)
          delete_fields(v)
          delete_deep_in(v)
        elsif v.is_a?(Array)
          if v.first.is_a?(Hash)
            v.each do |x|
              delete_fields(x)
              delete_deep_in(x)
            end
          end
        end
      end
    end

  end
end
