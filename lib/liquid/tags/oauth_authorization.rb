module Liquid
  class OauthAuthorization < CenitBasicTag

    tag :oauth_authorization

    def render(context)
      locals = {}
      context.environments.each { |e| locals.merge!(e) }
      Setup::OauthAuthorization.auth_header(locals)
    end

  end
end