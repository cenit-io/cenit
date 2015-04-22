class ApiController < ApplicationController
  respond_to :json

  def explore
    @json = doorkeeper_access_token.get("api/v1/#{params[:api]}").parsed
    respond_with @json
  end

  def write
    write_params = params.delete(:data)
    uri = URI("api/v1/#{params[:api]}")
    uri.query = write_params.to_query
    @json = doorkeeper_access_token.post(uri.to_s).parsed
    render json: @json
  end
end
