module Setup
  class Oauth2Provider < Setup::BaseOauthProvider
    include CenitUnscoped

    BuildInDataType.regist(self).referenced_by(:namespace, :name).excluding(:shared, :tenant, :clients)

    field :scope_separator, type: String

    validates_length_of :scope_separator, maximum: 1

    field :refresh_token_strategy, type: String, default: :none.to_s
    belongs_to :refresh_token_algorithm, class_name: Setup::Algorithm.to_s, inverse_of: nil

    validates_inclusion_of :refresh_token_strategy, in: ->(provider) { provider.refresh_token_strategy_enum }

    before_save do
      case refresh_token_strategy
      when :custom
        errors.add(:refresh_token_algorithm, "can't be blank") unless refresh_token_algorithm
      when :none
        if refresh_token_algorithm
          errors.add(:refresh_token_algorithm, 'not allowed')
          self.refresh_token_algorithm = nil
        end
      end
      errors.blank?
    end

    def refresh_token_strategy_enum
      ['Google v4', 'custom', 'default','none']
    end

    def refresh_token(authorization)
      if authorization.authorized?
        send(refresh_token_strategy.gsub(' ', '_').underscore + '_refresh_token', authorization)
      else
        fail "#{authorization.custom_title} not yet authorized"
      end
    end

    def none_refresh_token(authorization)
    end

    def custom_refresh_token(authorization)
      if alg = refresh_token_algorithm
        alg.run(authorization)
        authorization.save
      else
        fail "Refresh token algorithm is missing on #{custom_title}"
      end
    end

    def default_refresh_token(authorization)
      unless authorization.authorized_at + authorization.token_span > Time.now - 60
        fail "Missing client configuration" unless authorization.client
        http_response = HTTMultiParty.post(authorization.provider.token_endpoint,
                                           headers: { 'Content-Type' => 'application/x-www-form-urlencoded' },
                                           body: {
                                             grant_type: :refresh_token,
                                             refresh_token: authorization.refresh_token,
                                             client_id: authorization.client.attributes[:identifier],
                                             client_secret: authorization.client.attributes[:secret]
                                           }.to_param)
        body = JSON.parse(http_response.body)
        if http_response.code == 200
          authorization.authorized_at = Time.now
          authorization.token_type = body['token_type']
          authorization.access_token = body['access_token']
          authorization.token_span = body['expires_in']
          authorization.save
        else
          fail "(response code #{http_response.code} - #{body['error']}) #{body['error_description']}"
        end
      end
    rescue Exception => ex
      fail "Error refreshing token for #{authorization.custom_title}: #{ex.message}"
    end

    def google_v4_refresh_token(authorization)
      unless authorization.authorized_at + authorization.token_span > Time.now - 60
        fail "Missing client configuration" unless authorization.client
        http_response = HTTMultiParty.post('https://www.googleapis.com/oauth2/v4/token',
                                           headers: { 'Content-Type' => 'application/x-www-form-urlencoded' },
                                           body: {
                                                      grant_type: :refresh_token,
                                                      refresh_token: authorization.refresh_token,
                                                      client_id: authorization.client.attributes[:identifier],
                                                      client_secret: authorization.client.attributes[:secret]
                                                    }.to_param)
        body = JSON.parse(http_response.body)
        if http_response.code == 200
          authorization.authorized_at = Time.now
          authorization.token_type = body['token_type']
          authorization.access_token = body['access_token']
          authorization.token_span = body['expires_in']
          authorization.save
        else
          fail "(response code #{http_response.code} - #{body['error']}) #{body['error_description']}"
        end
      end
    rescue Exception => ex
      fail "Error refreshing token for #{authorization.custom_title}: #{ex.message}"
    end
  end
end