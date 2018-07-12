class RegistrationsController < Devise::RegistrationsController
  before_action :allow_x_frame

  def create
    verified = ENV['ENABLE_RERECAPTCHA'].to_b.blank? || ENV['RECAPTCHA_SITE_KEY'].blank? || verify_recaptcha(model: @contact)
    if verified
      super
    else
      redirect_to new_registration_path(User)
    end
  end

  protected

  def allow_x_frame
    response.headers.delete('X-Frame-Options')
  end
end