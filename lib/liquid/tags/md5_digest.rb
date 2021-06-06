module Liquid
  class Md5Digest < CenitBasicTag

    tag :md5_digest

    def render(context)
      Digest::MD5.base64digest(super).strip
    end

  end
end