require 'oauth2'

OAuth2::Response.register_parser(:text, 'text/html') do |body|
  MultiJson.load(body) rescue Rack::Utils.parse_query(body)
end

require 'oauth2/authenticator'

module OAuth2
  Authenticator.class_eval do

    alias_method :oauth2_apply, :apply

    def apply(params)
      case mode.to_sym
      when :none
        # Nothing to do here
        params
      else
        oauth2_apply(params)
      end
    end
  end
end