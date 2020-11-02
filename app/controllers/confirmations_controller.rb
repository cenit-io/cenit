class ConfirmationsController < Devise::ConfirmationsController
  before_action :allow_x_frame, :check_signed_in

  def create
    params[:user] = { email: resource_class.current.email }
    if request.xhr?
      self.resource = resource_class.send_confirmation_instructions(resource_params)
      yield resource if block_given?
      render body: nil, status: :ok
    else
      super
    end
  end

  def show
    if request.xhr? && !params[:confirmation_token]
      render json: { confirmed: resource_class.current.confirmed? }, status: :ok
    else
      super
    end
  end

  protected

  def check_signed_in
    signed_in? ||
      begin
        redirect_to new_session_path(User)
        false
      end
  end

  def allow_x_frame
    response.headers.delete('X-Frame-Options')
  end
end