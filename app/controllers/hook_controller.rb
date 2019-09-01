class HookController < ActionController::Base

  MAX_SIZE = 100 * 1024

  def digest
    status = :accepted
    json = {}
    if request.body.length > MAX_SIZE
      status = :bad_request
      json[:error] = 'Data is too long'
    else
      unless (token = params[:access_token])
        if (auth_header = request.headers['Authorization'])
          token_type, token = auth_header.to_s.squeeze(' ').strip.split(' ')
          token = nil unless token_type == 'Bearer' && token.present?
        end
      end
      if token
        begin
          if Cenit::Hook.digest(token, params[:slug], request.body.read, request.content_type)
            json[:status] = :accepted
          else
            json[:error] = "Hook token is invalid"
            status = :unauthorized
          end
        rescue Exception => ex
          report = Setup::SystemNotification.create_from(ex)
          json[:error] = "Ask for support by supplying this code: #{report.id}"
          status = :internal_server_error
        end
      else
        json[:error] = "Authorization token is malformed or missing"
        status = :unauthorized
      end
    end

    render json: json, status: status
  end
end
