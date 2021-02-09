class CaptchaController < ApplicationController

  def index
    if (token = params[:token])
      if (tkaptcha = CaptchaToken.where(token: token).first)
        tkaptcha.recode
        send_data Image.new(code: tkaptcha.code).data, type: 'image/jpeg', disposition: 'inline'
      else
        render json: { error: 'Invalid token' }, status: :not_found
      end
    else
      render json: { token: CaptchaToken.create.token }
    end
  end

  class Image < Captcha::Image

    def initialize(options = {})
      super(Captcha::Config.options.merge(options || {}))
    end

    def generate_code(options)
      if (code = options[:code])
        @code = code.chars
      else
        super
      end
    end
  end
end
