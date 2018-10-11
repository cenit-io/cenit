module Setup
  module AuthorizationClientCommon
    extend ActiveSupport::Concern

    included do

      field :identifier, type: String
      field :secret, type: String

      validates_uniqueness_of :name, scope: :provider
    end

    def write_attribute(name, value)
      @template_parameters = nil
      super
    end

    def inject_template_parameters(hash)
      hash['identifier'] ||= get_identifier
      hash['secret'] ||= get_secret
      hash['timestamp'] ||= (timestamp.to_f * 1000).to_i
      hash['utc_timestamp'] ||= (timestamp.utc.to_f * 1000).to_i
    end

    def timestamp
      @timestamp ||= Time.now
    end

    def reset_timestamp
      @timestamp = nil
    end

    def get_identifier
      attributes[:identifier]
    end

    def get_secret
      attributes[:secret]
    end
  end
end
