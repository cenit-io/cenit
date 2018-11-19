class ConfirmationsController < Devise::ConfirmationsController
  before_action :allow_x_frame

  def new
    if signed_in?
      super
    else
      redirect_to new_session_path(User)
    end
  end

  def create
    if signed_in?
      params[:user] = { email: resource_class.current.email }
      super
    else
      redirect_to new_session_path(User)
    end
  end

  protected

  def allow_x_frame
    response.headers.delete('X-Frame-Options')
  end
end