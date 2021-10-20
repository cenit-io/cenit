class RegistrationsController < Devise::RegistrationsController
  before_action :allow_x_frame

  def new
    return super if params[:return_to].to_s =~ /\/app\/ecapi/

    qs = "?#{request.query_string}" if request.query_string.present?

    redirect_to "https://server.cenit.io/users/sign_up#{qs}", status: 301
  end

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