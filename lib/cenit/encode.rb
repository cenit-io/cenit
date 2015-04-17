module Cenit
  class Encode < Liquid::Tag

    def initialize(tag_name, value, tokens)
      super
      @value = value
    end

    def render(context)
      values = @value.split(':')
      locals ={}
      context.environments.each { |e| locals.merge!(e) }
      key = locals[values[0]]
      secret = locals[values[1]]
      puts v = ::Base64.encode64(CGI::escape(key) + ':' + CGI::escape(secret) ).gsub("\n", '')
      v
    end
  end
end