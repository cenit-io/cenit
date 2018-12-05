require 'oauth2'

OAuth2::Response.register_parser(:text, 'text/html') do |body|
  MultiJson.load(body) rescue Rack::Utils.parse_query(body)
end