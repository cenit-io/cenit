require 'captcha/config'

class CaptchaController < ApplicationController

  def index
    if (token = params[:token])
      if (tkaptcha = CaptchaToken.where(token: token).first)
        tkaptcha.recode
        send_data build_image(tkaptcha.code), type: 'image/jpeg', disposition: 'inline'
      else
        render json: { error: 'Invalid token' }, status: :not_found
      end
    else
      render json: { token: CaptchaToken.create.token }
    end
  end

  private

  def build_image(code)
    options = Captcha::Config.options
    dimensions = options.fetch(:dimensions)
    letters = options.fetch(:letters)
    wave = options.fetch(:wave)

    canvas = Magick::Image.new(dimensions.fetch(:width), dimensions.fetch(:height)) do |info|
      info.background_color = options.fetch(:colors).fetch(:background)
    end
    text = Magick::Draw.new
    text.font(File.expand_path(options.fetch(:ttf)))
    text.pointsize(letters.fetch(:points))
    text.fill(options.fetch(:colors).fetch(:font))
    code.each_char.with_index do |character, index|
      text.text(index * letters.fetch(:width), letters.fetch(:baseline), character)
    end
    text.draw(canvas)

    wavelength = wave.fetch(:wavelength)
    distorted = canvas.wave(wave.fetch(:amplitude), rand(wavelength.begin...wavelength.end))
    image = distorted.implode(options.fetch(:implode))
    image.format = 'JPEG'
    image.to_blob
  ensure
    image&.destroy!
    distorted&.destroy!
    canvas&.destroy!
  end
end
