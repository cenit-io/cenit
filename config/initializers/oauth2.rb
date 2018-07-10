require 'oauth2'

OAuth2::Response::PARSERS[:text] = ->(body) { MultiJson.load(body) rescue Rack::Utils.parse_query(body) }
OAuth2::Response::CONTENT_TYPES['text/html'] = :text

module OAuth2
  class Client

    def request(verb, url, opts = {}) # rubocop:disable CyclomaticComplexity, MethodLength
      connection.response :logger, ::Logger.new($stdout) if ENV['OAUTH_DEBUG'] == 'true'

      url = connection.build_url(url, opts[:params]).to_s

      ::Tenant.notify(message: "OAuth 2.0 Request URL: #{url}", type: :notice)
      ::Tenant.notify(message: "Request options: #{opts.to_json}", type: :notice)

      response = connection.run_request(verb, url, opts[:body], opts[:headers]) do |req|
        yield(req) if block_given?
      end
      response = Response.new(response, :parse => opts[:parse])

      case response.status
      when 301, 302, 303, 307
        opts[:redirect_count] ||= 0
        opts[:redirect_count] += 1
        return response if opts[:redirect_count] > options[:max_redirects]
        if response.status == 303
          verb = :get
          opts.delete(:body)
        end
        request(verb, response.headers['location'], opts)
      when 200..299, 300..399
        # on non-redirecting 3xx statuses, just return the response
        response
      when 400..599
        error = Error.new(response)
        fail(error) if opts.fetch(:raise_errors, options[:raise_errors])
        response.error = error
        response
      else
        error = Error.new(response)
        fail(error, "Unhandled status code value of #{response.status}")
      end
    end
  end
end