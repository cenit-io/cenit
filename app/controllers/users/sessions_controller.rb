class Users::SessionsController < Devise::SessionsController
  before_action :allow_x_frame

  def allow_x_frame
    response.headers['X-FRAME-OPTIONS'] = 'ALLOWALL'
  end
end
