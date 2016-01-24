module Liquid
  class Md5Digest < CenitBasicTag

    tag :md5_digest

    def render(context)
      locals = {}
      context.environments.each { |e| locals.merge!(e) }
      Setup::AwsAuthorization.body_sign(locals[:body])
    end

    
  end
end