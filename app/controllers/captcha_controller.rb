class CaptchaController < ApplicationController

  def index
    if (token = params[:token])
      if (tkaptcha = CaptchaToken.where(token: token).first)
        tkaptcha.recode
        send_data build_image(code: tkaptcha.code).data, type: 'image/jpeg', disposition: 'inline'
      else
        render json: { error: 'Invalid token' }, status: :not_found
      end
    else
      render json: { token: CaptchaToken.create.token }
    end
  end

  private

  def build_image(options = {})
    require 'RMagick'
    captcha_module = Object.const_defined?(:Captcha) ? ::Captcha : Object.const_set(:Captcha, Module.new)
    if defined?(::Magick) && !captcha_module.const_defined?(:Magick, false)
      captcha_module.const_set(:Magick, ::Magick)
    end
    require 'captcha'

    image_class = Class.new(Captcha::Image) do
      def initialize(init_options = {})
        super(Captcha::Config.options.merge(init_options || {}))
      end

      def generate_code(gen_options)
        if (code = gen_options[:code])
          @code = code.chars
        else
          super
        end
      end
    end

    image_class.new(options)
  end
end
