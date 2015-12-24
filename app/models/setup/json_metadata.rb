module Setup
  module JsonMetadata
    extend ActiveSupport::Concern

    included do
      field :metadata

      before_save do
        if (metadata = attributes['metadata']).is_a?(Hash)
          attributes['metadata'] = metadata.to_json
        end
      end
    end

    def read_attribute(name)
      value = super
      if name.to_s == 'metadata' && value.is_a?(String)
        attributes['schema'] = value = JSON.parse(value) rescue value
      end
      value
    end
  end
end