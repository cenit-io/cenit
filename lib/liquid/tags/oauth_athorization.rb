module Liquid
  class OauthAthorization < CenitBasicTag

    tag :oauth_authorization

    def render(context)
      locals = {}
      context.environments.each { |e| locals.merge!(e) }
      locals.symbolize_keys!
      consumer = OAuth::Consumer.new(locals[:consumer_key], locals[:consumer_secret], site: locals[:url], scheme: :header)
      token_hash = {oauth_token: locals[:oauth_token], oauth_token_secret: locals[:oauth_token_secret]}
      access_token =  OAuth::AccessToken.from_hash(consumer, token_hash)
      locals[:path] = '/' + locals[:path] unless locals[:path].start_with?('/')
      request = consumer.send(:create_http_request, locals[:method], locals[:path], locals[:body])
      request.content_type = 'application/x-www-form-urlencoded'
      consumer.sign!(request, access_token, {})
      request['authorization']
    end

  end
end