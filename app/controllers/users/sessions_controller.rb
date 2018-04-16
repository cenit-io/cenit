class Users::SessionsController < Devise::SessionsController
  before_action :allow_x_frame

  protected

  def allow_x_frame
    response.headers.delete('X-Frame-Options')
  end
end
