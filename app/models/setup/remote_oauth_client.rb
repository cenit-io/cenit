module Setup
  class RemoteOauthClient < OauthClient
    include SharedEditable
    include Parameters
    include WithTemplateParameters
    include RailsAdmin::Models::Setup::RemoteOauthClientAdmin

    build_in_data_type.including(:provider).referenced_by(:_type, :provider, :name).protecting(:identifier, :secret)

    field :identifier, type: String
    field :secret, type: String

    parameters :request_token_parameters, :request_token_headers, :template_parameters

    # trace_references :request_token_parameters, :request_token_headers

    validates_uniqueness_of :name, scope: :provider

    def write_attribute(name, value)
      @template_parameters = nil
      super
    end

    def inject_template_parameters(hash)
      now = Time.now
      hash['identifier'] = get_identifier
      hash['secret'] = get_secret
      hash['timestamp'] = now.to_i
      hash['utc_timestamp'] = now.utc.to_i
      hash['iso8601_timestamp'] = now.utc.iso8601
    end

    def get_identifier
      attributes[:identifier]
    end

    def get_secret
      attributes[:secret]
    end

    def scope_title
      provider && provider.custom_title
    end

  end
end
