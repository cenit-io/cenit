require 'json'
require 'securerandom'

module Api
  module V3
    module RequestHelper

      DEFAULT_SCOPE = 'create read update delete digest'.freeze

      def oauth_bearer_token(scope: DEFAULT_SCOPE)
        @oauth_bearer_tokens ||= {}
        @oauth_bearer_tokens[scope] ||= begin
          user = ::User.current || ::User.all.first
          ::User.current = user if user
          app = ::Setup::Application.create!(
            namespace: 'Spec',
            name: "ApiV3Spec#{SecureRandom.hex(6)}"
          )
          access_grant = ::Cenit::OauthAccessGrant.create!(
            application_id: app.application_id,
            scope: scope
          )
          access = ::Cenit::OauthAccessToken.for(
            app.application_id,
            access_grant.scope,
            user
          )
          access[:access_token]
        end
      end

      def v3_auth_headers(scope: DEFAULT_SCOPE, headers: {})
        {
          'Authorization' => "Bearer #{oauth_bearer_token(scope: scope)}",
          'Accept' => 'application/json'
        }.merge(headers)
      end

      def v3_digest_headers(
        digest_options: nil,
        parser_options: nil,
        template_options: nil,
        query_selector: nil,
        headers: {}
      )
        digest_headers = headers.dup
        digest_headers['X-Digest-Options'] = JSON.dump(digest_options) if digest_options.is_a?(Hash)
        digest_headers['X-Parser-Options'] = JSON.dump(parser_options) if parser_options.is_a?(Hash)
        digest_headers['X-Template-Options'] = JSON.dump(template_options) if template_options.is_a?(Hash)
        digest_headers['X-Query-Selector'] = JSON.dump(query_selector) if query_selector.is_a?(Hash)
        digest_headers
      end

      def get_json(path, params: nil, headers: {})
        get path, params: params, headers: headers, as: :json
      end

      def post_json(path, params: nil, headers: {})
        post path, params: params, headers: headers, as: :json
      end

      def delete_json(path, params: nil, headers: {})
        delete path, params: params, headers: headers, as: :json
      end

      def json_response
        JSON.parse(response.body.presence || '{}')
      end

      def expect_status_in(*statuses)
        code = response.status
        expected_codes = statuses.flatten.map { |s| Rack::Utils.status_code(s) }
        expect(expected_codes).to include(code), "expected status in #{expected_codes.inspect}, got #{code} with body #{response.body}"
      end

      def resolve_data_type_id_via_api(namespace:, name:, headers:)
        get_json(
          '/api/v3/setup/data_type',
          params: { namespace: namespace, name: name, limit: 1 },
          headers: headers
        )
        expect_status_in(:ok)
        resolve_id_from_hash(json_response.dig('items', 0))
      end

      def resolve_id_from_hash(hash)
        return nil unless hash.is_a?(Hash)
        hash['id'] ||
          hash['_id'] ||
          hash.dig('id', '$oid') ||
          hash.dig('_id', '$oid')
      end
    end
  end
end
