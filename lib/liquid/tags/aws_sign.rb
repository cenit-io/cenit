module Liquid
  class AwsSign < CenitBasicTag

    tag :aws_sign

    def render(context)
      locals = {}
      context.environments.each { |e| locals.merge!(e) }
      Setup::AwsAuthorization.sign(locals)
    end
  end
end